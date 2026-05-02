# frozen_string_literal: true

require_relative '../../app/services/event_service'
require_relative '../../app/services/account_service'
require_relative '../../app/services/attendance_record_service'
require_relative '../spec_helper'

describe 'TickIt Services' do
  before(:each) do
    TickIt::Api::DB.run('PRAGMA foreign_keys = OFF')
    TickIt::Api::DB[:attendance_records].delete
    TickIt::Api::DB[:events].delete
    TickIt::Api::DB[:accounts].delete
    TickIt::Api::DB.run('PRAGMA foreign_keys = ON')
  end
  describe TickIt::EventService do
    describe '.parse_time' do
      it 'parses Unix timestamps' do
        timestamp = Time.now.to_i
        result = TickIt::EventService.parse_time(timestamp)
        expect(result).to be_a(Time)
        expect(result.to_i).to eq(timestamp)
      end

      it 'parses ISO 8601 strings' do
        time_str = '2026-06-15T09:00:00Z'
        result = TickIt::EventService.parse_time(time_str)
        expect(result).to be_a(Time)
        expect(result.iso8601).to eq(time_str)
      end

      it 'raises error for unsupported format' do
        expect { TickIt::EventService.parse_time({}) }.to raise_error(ArgumentError)
      end
    end

    describe '.create_event' do
      it 'creates an event successfully' do
        event = TickIt::EventService.create_event(
          name: 'Test Event',
          location: 'Test Room',
          start_time: Time.now,
          end_time: Time.now + 3600,
          description: 'Test Description'
        )

        expect(event).to be_a(TickIt::Event)
        expect(event.name).to eq('Test Event')
        expect(event.location).to eq('Test Room')
        expect(event.description).to eq('Test Description')
      end

      it 'raises error when required fields are missing' do
        expect do
          TickIt::EventService.create_event(
            name: 'Test Event',
            location: '',
            start_time: Time.now,
            end_time: Time.now + 3600
          )
        end.to raise_error(ArgumentError, /Missing required fields/)
      end
    end

    describe '.find_event' do
      it 'finds an existing event' do
        created_event = TickIt::EventService.create_event(
          name: 'Findable Event',
          location: 'Room 42',
          start_time: Time.now,
          end_time: Time.now + 3600
        )

        found_event = TickIt::EventService.find_event(created_event.id)
        expect(found_event).to eq(created_event)
      end

      it 'returns nil for non-existent event' do
        result = TickIt::EventService.find_event('nonexistent-id')
        expect(result).to be_nil
      end
    end

    describe '.all_events' do
      it 'returns all events as API hashes' do
        TickIt::EventService.create_event(
          name: 'Event 1',
          location: 'Room 1',
          start_time: Time.now,
          end_time: Time.now + 3600
        )
        TickIt::EventService.create_event(
          name: 'Event 2',
          location: 'Room 2',
          start_time: Time.now,
          end_time: Time.now + 3600
        )

        all_events = TickIt::EventService.all_events
        expect(all_events).to be_an(Array)
        expect(all_events.length).to eq(2)
        expect(all_events.first).to be_a(Hash)
        expect(all_events.first).to have_key(:id)
        expect(all_events.first).to have_key(:name)
      end
    end
  end

  describe TickIt::AccountService do
    describe '.create_account' do
      it 'creates an account successfully' do
        account = TickIt::AccountService.create_account(
          email: 'test@example.com',
          password: 'secure_password'
        )

        expect(account).to be_a(TickIt::Account)
        expect(account.email).to eq('test@example.com')
        expect(account.role).to eq('member')
      end

      it 'creates an account with custom role' do
        account = TickIt::AccountService.create_account(
          email: 'admin@example.com',
          password: 'admin_password',
          role: 'admin'
        )

        expect(account.role).to eq('admin')
      end

      it 'raises error when email is empty' do
        expect do
          TickIt::AccountService.create_account(
            email: '',
            password: 'password'
          )
        end.to raise_error(ArgumentError)
      end

      it 'raises error when password is empty' do
        expect do
          TickIt::AccountService.create_account(
            email: 'test@example.com',
            password: ''
          )
        end.to raise_error(ArgumentError)
      end

      it 'prevents duplicate emails' do
        TickIt::AccountService.create_account(
          email: 'duplicate@example.com',
          password: 'password1'
        )

        expect do
          TickIt::AccountService.create_account(
            email: 'duplicate@example.com',
            password: 'password2'
          )
        end.to raise_error(StandardError, /already exists/)
      end
    end

    describe '.find_account' do
      it 'finds an existing account' do
        created_account = TickIt::AccountService.create_account(
          email: 'findme@example.com',
          password: 'password'
        )

        found_account = TickIt::AccountService.find_account(created_account.id)
        expect(found_account).to eq(created_account)
      end

      it 'returns nil for non-existent account' do
        result = TickIt::AccountService.find_account('nonexistent-id')
        expect(result).to be_nil
      end
    end

    describe '.authenticate' do
      it 'authenticates with correct password' do
        TickIt::AccountService.create_account(
          email: 'auth@example.com',
          password: 'correct_password'
        )

        account = TickIt::AccountService.authenticate(
          email: 'auth@example.com',
          password: 'correct_password'
        )
        expect(account).not_to be_nil
        expect(account.email).to eq('auth@example.com')
      end

      it 'returns nil with incorrect password' do
        TickIt::AccountService.create_account(
          email: 'auth@example.com',
          password: 'correct_password'
        )

        account = TickIt::AccountService.authenticate(
          email: 'auth@example.com',
          password: 'wrong_password'
        )
        expect(account).to be_nil
      end
    end
  end

  describe TickIt::AttendanceRecordService do
    let!(:test_event) do
      TickIt::EventService.create_event(
        name: 'Attendance Test Event',
        location: 'Test Room',
        start_time: Time.now,
        end_time: Time.now + 3600
      )
    end

    describe '.create_record' do
      it 'creates an attendance record successfully' do
        record = TickIt::AttendanceRecordService.create_record(
          student_id: 'STU001',
          event_id: test_event.id
        )

        expect(record).to be_a(TickIt::AttendanceRecord)
        expect(record.student_number).to eq('STU001')
        expect(record.event_id).to eq(test_event.id)
      end

      it 'uses first event when event_id is not provided' do
        record = TickIt::AttendanceRecordService.create_record(
          student_id: 'STU002'
        )

        expect(record.event_id).to eq(test_event.id)
      end

      it 'raises error when student_id is empty' do
        expect do
          TickIt::AttendanceRecordService.create_record(
            student_id: '',
            event_id: test_event.id
          )
        end.to raise_error(ArgumentError)
      end

      it 'raises error when no event is available' do
        TickIt::Api::DB[:events].delete

        expect do
          TickIt::AttendanceRecordService.create_record(
            student_id: 'STU003'
          )
        end.to raise_error(StandardError, /No event available/)
      end
    end

    describe '.find_record' do
      it 'finds an existing attendance record' do
        created_record = TickIt::AttendanceRecordService.create_record(
          student_id: 'STU004',
          event_id: test_event.id
        )

        found_record = TickIt::AttendanceRecordService.find_record(created_record.id)
        expect(found_record).to eq(created_record)
      end

      it 'returns nil for non-existent record' do
        result = TickIt::AttendanceRecordService.find_record('nonexistent-id')
        expect(result).to be_nil
      end
    end

    describe '.records_for_student' do
      it 'retrieves all records for a student' do
        TickIt::AttendanceRecordService.create_record(
          student_id: 'STU005',
          event_id: test_event.id
        )

        second_event = TickIt::EventService.create_event(
          name: 'Second Event',
          location: 'Room 2',
          start_time: Time.now + 7200,
          end_time: Time.now + 10_800
        )

        TickIt::AttendanceRecordService.create_record(
          student_id: 'STU005',
          event_id: second_event.id
        )

        records = TickIt::AttendanceRecordService.records_for_student('STU005')
        expect(records.length).to eq(2)
        expect(records.all? { |r| r[:student_id] == 'STU005' }).to be(true)
      end
    end

    describe '.records_for_event' do
      it 'retrieves all records for an event' do
        TickIt::AttendanceRecordService.create_record(
          student_id: 'STU006',
          event_id: test_event.id
        )
        TickIt::AttendanceRecordService.create_record(
          student_id: 'STU007',
          event_id: test_event.id
        )

        records = TickIt::AttendanceRecordService.records_for_event(test_event.id)
        expect(records.length).to eq(2)
        expect(records.all? { |r| r[:event_id] == test_event.id }).to be(true)
      end
    end
  end
end
