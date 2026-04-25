# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../../lib/secure_db'
require_relative '../../lib/security_log'
require_relative '../models/event'
require_relative '../models/attendance_record'
require_relative '../models/account'

module TickIt
  # The main TickIt API class that handles attendance record endpoints
  class Api < Roda
    plugin :halt

    # Parse JSON time values (ISO 8601 string or Unix timestamp)
    def self.parse_event_time(value)
      case value
      when Integer, Float then Time.at(value)
      when String then Time.iso8601(value)
      else
        raise ArgumentError, 'Unsupported time format'
      end
    end

    route do |r|
      response['Content-Type'] = 'application/json' # set default format
      
      begin
        r.root do # alive
          { message: 'TickIt API is up and running!' }.to_json
        end

        # /api/v1/...
        r.on 'api' do
          r.on 'v1' do
            
            # --- EVENTS ROUTES ---
            r.on 'events' do
              r.is String do |id_segment|
                r.get do
                  id_str = id_segment.sub(/\.json\z/, '')
                  event = TickIt::Event.with_pk(id_str)
                  if event
                    { event: event.to_api_hash }.to_json
                  else
                    response.status = 404
                    { error: 'Event not found' }.to_json
                  end
                end
              end

              r.is do
                r.get do
                  events = TickIt::Event.order(:id).map(&:to_api_hash)
                  { events: events }.to_json
                end

                r.post do
                  body = JSON.parse(r.body.read, symbolize_names: true)
                  required = %i[name location start_time end_time]
                  missing = required.select do |key|
                    val = body[key]
                    val.nil? || (val.is_a?(String) && val.strip.empty?)
                  end
                  if missing.any?
                    response.status = 400
                    next({ error: 'Missing required fields', missing: missing.map(&:to_s) }.to_json)
                  end

                  start_t = TickIt::Api.parse_event_time(body[:start_time])
                  end_t = TickIt::Api.parse_event_time(body[:end_time])
                  event = TickIt::Event.create(
                    name: body[:name].to_s.strip,
                    location: body[:location].to_s.strip,
                    start_time: start_t,
                    end_time: end_t,
                    description: body[:description]&.to_s
                  )

                  response.status = 201
                  { message: 'Event created', event: event.to_api_hash }.to_json
                rescue JSON::ParserError
                  response.status = 400
                  { error: 'Invalid JSON format' }.to_json
                rescue Sequel::MassAssignmentRestriction => e
                  TickIt::SecurityLog.log_mass_assignment_warning('Event', body.keys.map(&:to_s), TickIt::Event.allowed_columns)
                  response.status = 400
                  { error: 'Illegal mass assignment detected' }.to_json
                rescue ArgumentError
                  response.status = 400
                  { error: 'Invalid start_time or end_time' }.to_json
                rescue StandardError => e
                  TickIt::SecurityLog.log_error(e, { model: 'Event', action: 'create' })
                  response.status = 500
                  { error: 'An unexpected error occurred' }.to_json
                end
              end
            end

            # --- ATTENDANCES ROUTES ---
            r.on 'attendances' do
              r.is String do |id_with_ext| # get by id
                r.get do
                  id = id_with_ext.sub('.json', '')
                  record = TickIt::AttendanceRecord.with_pk_string(id)
                  if record
                    record.api_json_hash.to_json
                  else
                    response.status = 404 # not found
                    { error: 'Attendance record not found' }.to_json
                  end
                end
              end

              r.is do
                r.get do # get all
                  ids = TickIt::AttendanceRecord.order(:id).select_map(:id)
                  { attendance_ids: ids }.to_json
                end

                r.post do # create new record
                  request_body = JSON.parse(r.body.read, symbolize_names: true)
                  
                  if request_body.key?(:status)
                    TickIt::AttendanceRecord.new.set(status: request_body[:status])
                  end

                  event =
                    if request_body[:event_id]
                      
                      TickIt::Event.with_pk(request_body[:event_id].to_s)
                    else
                      TickIt::Event.order(:id).first
                    end
                    
                  unless event
                    response.status = 400
                    next({ error: 'No event available; create an event or pass event_id' }.to_json)
                  end

                  check_in =
                    if request_body[:timestamp]
                      Time.at(request_body[:timestamp])
                    else
                      Time.now
                    end

                  
                  new_record = TickIt::AttendanceRecord.create(
                    student_number: request_body[:student_id].to_s,
                    event_id: event.id,
                    check_in_time: check_in
                  )

                  response.status = 201
                  { message: 'Attendance successfully recorded', id: new_record.id }.to_json
                rescue JSON::ParserError # failed
                  response.status = 400
                  { error: 'Invalid JSON format' }.to_json
                rescue Sequel::MassAssignmentRestriction => e
                  TickIt::SecurityLog.log_mass_assignment_warning('AttendanceRecord', request_body.keys.map(&:to_s), TickIt::AttendanceRecord.allowed_columns)
                  response.status = 400
                  { error: 'Illegal mass assignment detected' }.to_json
                rescue StandardError => e
                  TickIt::SecurityLog.log_error(e, { model: 'AttendanceRecord', action: 'create' })
                  response.status = 500
                  { error: 'An unexpected error occurred' }.to_json
                end
              end
            end

          r.on 'accounts' do
            # GET /api/v1/accounts/:id
            
            r.get String do |account_id|
              account = TickIt::Account.first(id: account_id)
              
              if account.nil?
                response.status = 404
                r.halt({ error: 'Account not found' }.to_json)
              end

              
              response.status = 200
              {
                account: {
                  id: account.id,
                  email: account.email
                }
              }.to_json
            end

            # POST /api/v1/accounts
            # 註冊一個新帳號
            r.post do
              begin
                account_data = JSON.parse(r.body.read)
                
                # 建立帳號，觸發我們寫好的加密機制
                account = TickIt::Account.create(
                  email: account_data['email'],
                  password: account_data['password']
                )

                response.status = 201
                { 
                  message: 'Account created successfully', 
                  account: { id: account.id, email: account.email } 
                }.to_json
                
              rescue JSON::ParserError
                response.status = 400
                { error: 'Invalid JSON format' }.to_json
              rescue Sequel::UniqueConstraintViolation
                response.status = 400
                { error: 'Email already exists' }.to_json
              end
            end
          end

          end
        end
      rescue StandardError => e
        # Catch any unhandled errors in the API
        TickIt::SecurityLog.log_error(e, { endpoint: 'unknown', method: request.request_method })
        response.status = 500
        { error: 'An unexpected error occurred' }.to_json
      end
    end
  end
end