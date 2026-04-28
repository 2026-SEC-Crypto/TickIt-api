# frozen_string_literal: true

require 'rack/test'
require 'json'
require_relative '../../app/controllers/app'
require_relative '../spec_helper'

TABLES_CLEAR_ORDER = %i[attendance_records events accounts].freeze

RSpec.describe 'TickIt API - Accounts & Students' do
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
  end
end
