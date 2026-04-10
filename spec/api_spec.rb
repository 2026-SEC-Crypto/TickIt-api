# frozen_string_literal: true

require 'rack/test'
require 'json'
require 'fileutils'
require 'yaml'
require_relative '../app/controllers/app'
require_relative '../app/models/attendance_record'

# Load seed data
DATA = YAML.safe_load_file('app/db/seeds/attendance_records.yml')['attendance_records']

RSpec.describe 'TickIt API' do
  include Rack::Test::Methods

  def app
    TickIt::Api
  end

  # Setup: Create test data directory and clean before tests
  before(:all) do
    @test_store_dir = 'app/db/store'
    FileUtils.mkdir_p(@test_store_dir)
  end

  before(:each) do
    # Clean up before each test
    Dir.glob("#{@test_store_dir}/*.txt").each { |file| File.delete(file) }
  end

  after(:all) do
    # Clean up after all tests
    Dir.glob("#{@test_store_dir}/*.txt").each { |file| File.delete(file) }
  end

  describe 'HAPPY Path Tests' do
    # Test 1: Root route works
    describe 'GET /' do
      it 'returns 200 OK and confirms API is running' do
        get '/'
        expect(last_response.status).to eq(200)

        body = JSON.parse(last_response.body)
        expect(body['message']).to eq('TickIt API is up and running!')
      end
    end

    # Test 2: Create a resource (POST method) works
    describe 'POST /api/v1/attendances' do
      it 'creates a new attendance record successfully' do
        payload = DATA[0].to_json

        post '/api/v1/attendances', payload, { 'CONTENT_TYPE' => 'application/json' }

        expect(last_response.status).to eq(201)

        body = JSON.parse(last_response.body)
        expect(body['message']).to eq('Attendance successfully recorded')
        expect(body).to have_key('id')
        @created_id = body['id']
      end
    end

    # Test 3: Get a single resource (GET) works
    describe 'GET /api/v1/attendances/{id}' do
      it 'retrieves a single attendance record by ID' do
        # First, create a record using seeded data
        payload = DATA[1].to_json
        post '/api/v1/attendances', payload, { 'CONTENT_TYPE' => 'application/json' }

        created_body = JSON.parse(last_response.body)
        record_id = created_body['id']

        # Now retrieve it
        get "/api/v1/attendances/#{record_id}"

        expect(last_response.status).to eq(200)

        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(record_id)
        expect(body['student_id']).to eq(DATA[1]['student_id'])
        expect(body['location']).to eq(DATA[1]['location'])
      end
    end

    # Test 4: Get a list of resources (GET) works
    describe 'GET /api/v1/attendances' do
      it 'retrieves all attendance record IDs' do
        # Create multiple records using seeded data
        DATA.each do |record_data|
          payload = record_data.to_json
          post '/api/v1/attendances', payload, { 'CONTENT_TYPE' => 'application/json' }
        end

        # Retrieve all
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
    # Test 5: GET non-existent resource fails
    describe 'GET /api/v1/attendances/{invalid_id}' do
      it 'returns 404 when record does not exist' do
        get '/api/v1/attendances/nonexistent_id_12345'

        expect(last_response.status).to eq(404)

        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Attendance record not found')
      end
    end
  end
end
