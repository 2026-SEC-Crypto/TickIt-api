# frozen_string_literal: true

require 'rack/test'
require 'json'
require_relative '../../app/controllers/app'
require_relative '../spec_helper'

TABLES_CLEAR_ORDER = %i[attendance_records events accounts].freeze

RSpec.describe 'TickIt API - Events' do
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

        # Expect the error message format used for mass assignment
        expect(body['error']).to eq('Illegal mass assignment detected')
        expect(TickIt::Event.count).to eq(before_count)
      end

      it 'returns 400 when required fields are missing' do
        payload = {
          name: 'Incomplete',
          location: 'Nowhere'
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
