# frozen_string_literal: true

require 'rack/test'
require 'json'
require 'yaml'
require_relative '../../app/controllers/app'
require_relative '../spec_helper'

# Load seed-style payloads
DATA = YAML.safe_load_file('app/db/seeds/attendance_records.yml')['attendance_records']

TABLES_CLEAR_ORDER = %i[attendance_records events accounts].freeze

RSpec.describe 'TickIt API - Attendances' do
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
  end

  describe 'SAD Path Tests' do
    describe 'GET /api/v1/attendances' do
      it 'returns an empty attendance id list when there are no records' do
        get '/api/v1/attendances'

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['attendance_ids']).to eq([])
      end
    end

    describe 'POST /api/v1/attendances' do
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
  end
end
