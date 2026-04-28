# frozen_string_literal: true

require 'rack/test'
require 'json'
require 'yaml'
require 'open3'
require 'tmpdir'
require 'digest'
require_relative '../app/controllers/app'
require_relative 'spec_helper'

# Load seed-style payloads (student_id is student_number in the API)
DATA = YAML.safe_load_file('app/db/seeds/attendance_records.yml')['attendance_records']

# Foreign keys reference students/events — delete dependents first
TABLES_CLEAR_ORDER = %i[attendance_records events accounts].freeze

RSpec.describe 'TickIt API' do
  include Rack::Test::Methods

  def app
    TickIt::Api
  end

  before(:each) do
    db = TickIt::Api::DB
    TABLES_CLEAR_ORDER.each { |table| db[table].delete }

    # Create a test event using EventService
    @test_event = TickIt::EventService.create_event(
      name: 'API Test Event',
      location: 'Room 101',
      start_time: Time.now,
      end_time: Time.now + 3600
    )
  end

  describe 'HAPPY Path Tests' do
    describe 'Account API' do
      it 'POST /api/v1/accounts - creates a new account securely' do
        payload = {
          email: 'new_user@example.com',
          password: 'super_secure_password_123'
        }.to_json

        post '/api/v1/accounts', payload, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        body = JSON.parse(last_response.body)

        expect(body['message']).to eq('Account created successfully')
        expect(body['account']['id']).not_to be_nil
        expect(body['account']['email']).to eq('new_user@example.com')
        expect(body['account']['password']).to be_nil
        expect(body['account']['password_hash']).to be_nil
      end

      it 'GET /api/v1/accounts/:id - retrieves account info without leaking secrets' do
        account = TickIt::AccountService.create_account(
          email: 'search_me@example.com',
          password: 'test_password'
        )

        get "/api/v1/accounts/#{account.id}"

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)

        expect(body['account']['id']).to eq(account.id)
        expect(body['account']['email']).to eq('search_me@example.com')
        expect(body['account']['password']).to be_nil
        expect(body['account']['password_hash']).to be_nil
      end

      it 'GET /api/v1/accounts/:id - returns 404 for missing account' do
        get '/api/v1/accounts/nonexistent-account-id'

        expect(last_response.status).to eq(404)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Account not found')
      end
    end

    describe 'Student courses/events API' do
      it 'GET /api/v1/students/:student_id/events - returns attended events for a student' do
        TickIt::AttendanceRecordService.create_record(
          student_id: 'STU_COURSE_001',
          event_id: @test_event.id
        )

        second_event = TickIt::EventService.create_event(
          name: 'API Course 2',
          location: 'Room 303',
          start_time: Time.now + 7200,
          end_time: Time.now + 10_800
        )

        TickIt::AttendanceRecordService.create_record(
          student_id: 'STU_COURSE_001',
          event_id: second_event.id
        )

        get '/api/v1/students/STU_COURSE_001/events'

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['student_id']).to eq('STU_COURSE_001')
        expect(body['events']).to be_an(Array)
        expect(body['events'].length).to eq(2)
      end

      it 'GET /api/v1/students/:student_id/courses - alias route returns courses' do
        TickIt::AttendanceRecordService.create_record(
          student_id: 'STU_COURSE_002',
          event_id: @test_event.id
        )

        get '/api/v1/students/STU_COURSE_002/courses'

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['student_id']).to eq('STU_COURSE_002')
        expect(body['courses']).to be_an(Array)
        expect(body['courses'].first['id']).to eq(@test_event.id)
      end
    end

    describe 'DATABASE_URL configuration' do
      it 'HAPPY: boot fails safely when DATABASE_URL is not in environment (guard works)' do
        Dir.mktmpdir do |dir|
          secrets = File.join(dir, 'secrets.yml')
          File.write(secrets, "test:\n  # no DATABASE_URL — intentional for this spec\n")

          project_root = File.expand_path('..', __dir__)
          boot = File.expand_path('support/boot_without_database_url.rb', __dir__)
          env = {
            'RACK_ENV' => 'test',
            'BUNDLE_GEMFILE' => File.join(project_root, 'Gemfile')
          }

          stdout, stderr, status = Dir.chdir(project_root) do
            Open3.capture3(env, Gem.ruby, boot, secrets)
          end

          expect(status.success?).to be(false)
          expect(stdout + stderr).to include('DATABASE_URL is missing')
        end
      end
    end

    describe 'GET /' do
      it 'returns a valid JSON welcome / status message on the root route' do
        get '/'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')

        body = JSON.parse(last_response.body)
        expect(body).to be_a(Hash)
        expect(body['message']).to be_a(String)
        expect(body['message'].strip).not_to be_empty
        expect(body['message']).to eq('TickIt API is up and running!')
      end
    end

    describe 'POST /api/v1/attendances' do
      it 'creates a new attendance record successfully' do
        payload = DATA[0].reject { |k, _| k == 'status' }.to_json

        post '/api/v1/attendances', payload, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)

        body = JSON.parse(last_response.body)
        expect(body['message']).to eq('Attendance successfully recorded')
        expect(body).to have_key('id')
      end
    end

    describe 'GET /api/v1/attendances/{id}' do
      it 'retrieves a single attendance record by ID' do
        payload = DATA[1].reject { |k, _| k == 'status' }.to_json
        post '/api/v1/attendances', payload, { 'CONTENT_TYPE' => 'application/json' }

        created_body = JSON.parse(last_response.body)
        record_id = created_body['id']

        get "/api/v1/attendances/#{record_id}"

        expect(last_response.status).to eq(200)

        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(record_id)
        expect(body['student_id']).to eq(DATA[1]['student_id'])
        expect(body['status']).to eq('present')
      end
    end

    describe 'GET /api/v1/attendances' do
      it 'retrieves all attendance record IDs' do
        DATA.each do |record_data|
          payload = record_data.reject { |k, _| k == 'status' }.to_json
          post '/api/v1/attendances', payload, { 'CONTENT_TYPE' => 'application/json' }
        end

        get '/api/v1/attendances'

        expect(last_response.status).to eq(200)

        body = JSON.parse(last_response.body)
        expect(body).to have_key('attendance_ids')
        expect(body['attendance_ids'].length).to eq(DATA.length)
        expect(body['attendance_ids']).to be_an(Array)
      end
    end

    describe 'GET /api/v1/events' do
      it 'returns a JSON list of all events' do
        TickIt::EventService.create_event(
          name: 'Second Event',
          location: 'Room 202',
          start_time: Time.utc(2026, 5, 1, 10, 0, 0),
          end_time: Time.utc(2026, 5, 1, 12, 0, 0)
        )

        get '/api/v1/events'

        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')

        body = JSON.parse(last_response.body)
        expect(body['events']).to be_an(Array)
        expect(body['events'].length).to eq(2)

        names = body['events'].map { |e| e['name'] }
        expect(names).to include('API Test Event', 'Second Event')
      end
    end

    describe 'GET /api/v1/events/:id' do
      it 'returns a single event when the id exists' do
        event = TickIt::Event.first!

        get "/api/v1/events/#{event.id}"

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['event']).to be_a(Hash)
        expect(body['event']['id']).to eq(event.id)
        expect(body['event']['name']).to eq('API Test Event')
        expect(body['event']['location']).to eq('Room 101')
        expect(body['event']).to have_key('start_time')
        expect(body['event']).to have_key('end_time')
      end
    end

    describe 'POST /api/v1/events' do
      it 'creates an event and returns 201 with the new resource' do
        payload = {
          name: 'Security Seminar',
          location: 'Auditorium',
          start_time: '2026-06-15T09:00:00Z',
          end_time: '2026-06-15T11:30:00Z',
          description: 'Hands-on lab'
        }.to_json

        post '/api/v1/events', payload, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)
        body = JSON.parse(last_response.body)
        expect(body['message']).to eq('Event created')
        expect(body['event']['name']).to eq('Security Seminar')
        expect(body['event']['location']).to eq('Auditorium')
        expect(body['event']['description']).to eq('Hands-on lab')
        expect(body['event']['id']).to be_a(String)

        created = TickIt::Event.with_pk(body['event']['id'])
        expect(created).not_to be_nil
        expect(created.name).to eq('Security Seminar')
      end
    end
  end

  describe 'SAD Path Tests' do
    describe 'GET /' do
      it 'does not treat root as a JSON POST endpoint' do
        post '/', '{}', { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).not_to eq(200)
      end
    end

    describe 'GET /api/v1/attendances' do
      it 'returns an empty attendance id list when there are no records' do
        get '/api/v1/attendances'

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['attendance_ids']).to eq([])
      end
    end

    describe 'POST /api/v1/attendances' do
      it 'returns 400 and does not create rows on illegal mass assignment' do
        before_count = TickIt::Event.count

        # Include an illegal attribute (e.g., trying to force a specific ID)
        payload = {
          name: 'Hacked Event',
          location: 'Secret Base',
          start_time: '2026-05-01T10:00:00Z',
          end_time: '2026-05-01T12:00:00Z',
          id: 'malicious_id_injection'
        }.to_json

        post '/api/v1/events', payload, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)

        # Expect the same error message format you use for attendance records
        expect(body['error']).to eq('Illegal mass assignment detected')
        expect(TickIt::Event.count).to eq(before_count)
      end
      it 'returns 400 when the body is not valid JSON' do
        post '/api/v1/attendances', 'not-json', { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Invalid JSON format')
      end

      it 'returns 400 and does not create rows on illegal mass assignment' do
        before_count = TickIt::AttendanceRecord.count
        payload = {
          student_id: DATA[0]['student_id'],
          event_id: TickIt::Event.first.id,
          status: 'verified'
        }.to_json

        post '/api/v1/attendances', payload, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Illegal mass assignment detected')
        expect(TickIt::AttendanceRecord.count).to eq(before_count)
      end
    end

    describe 'GET /api/v1/attendances/{invalid_id}' do
      it 'returns 404 when record does not exist' do
        get '/api/v1/attendances/nonexistent_id_12345'

        expect(last_response.status).to eq(404)

        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Attendance record not found')
      end

      it 'returns 404 when id contains SQL injection payload' do
        get '/api/v1/attendances/1%20OR%201=1'

        expect(last_response.status).to eq(404)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Attendance record not found')
      end
    end

    describe 'GET /api/v1/events' do
      it 'returns an empty list when no events exist' do
        TickIt::Api::DB[:events].delete

        get '/api/v1/events'

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)['events']).to eq([])
      end
    end

    describe 'GET /api/v1/events/:id' do
      it 'returns 404 when the event id does not exist' do
        get '/api/v1/events/999999'

        expect(last_response.status).to eq(404)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Event not found')
      end

      it 'returns 404 when id contains SQL injection payload' do
        get '/api/v1/events/1%20OR%201=1'

        expect(last_response.status).to eq(404)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Event not found')
      end
    end

    describe 'POST /api/v1/events' do
      it 'returns 400 when required fields are missing' do
        payload = {
          name: 'Incomplete',
          location: 'Nowhere'
          # missing start_time, end_time
        }.to_json

        post '/api/v1/events', payload, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Missing required fields')
        expect(body['missing']).to include('start_time', 'end_time')
      end

      it 'returns 400 when JSON is invalid' do
        post '/api/v1/events', 'not{json', { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Invalid JSON format')
      end
    end
  end
end
