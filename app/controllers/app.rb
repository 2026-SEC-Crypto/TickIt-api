# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../../lib/security_log'
require_relative '../models/event'
require_relative '../models/attendance_record'
require_relative '../models/account'
require_relative '../services/event_service'
require_relative '../services/account_service'
require_relative '../services/attendance_record_service'

module TickIt
  class Api < Roda
    plugin :halt

    route do |r|
      response['Content-Type'] = 'application/json'

      begin
        r.root do
          { message: 'TickIt API is up and running!' }.to_json
        end

        r.on 'api' do
          r.on 'v1' do
            r.on 'events' do
              r.is String do |id_segment|
                r.get do
                  id = id_segment.sub(/\.json\z/, '')
                  event = TickIt::EventService.find_event(id)
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
                  { events: TickIt::EventService.all_events }.to_json
                end

                r.post do
                  body = JSON.parse(r.body.read, symbolize_names: true)
                  
                  # 1. Check for missing required fields 🌟
                  required = %i[name location start_time end_time]
                  missing = required.select do |field|
                    value = body[field]
                    value.nil? || (value.is_a?(String) && value.strip.empty?)
                  end

                  if missing.any?
                    response.status = 400
                    return({ error: 'Missing required fields', missing: missing.map(&:to_s) }.to_json)
                  end

                  # 2. Check for illegal mass assignment keys 🚨
                  allowed_keys = %i[name location start_time end_time description]
                  illegal_keys = body.keys - allowed_keys

                  if illegal_keys.any?
                    # Security log for mass assignment attempt
                    TickIt::SecurityLog.log_mass_assignment_warning(
                      'Event',
                      body.keys.map(&:to_s),
                      allowed_keys.map(&:to_s)
                    )
                    response.status = 400
                    return({ error: 'Illegal mass assignment detected' }.to_json)
                  end

                  # 3. Process the valid request to create an event
                  event = TickIt::EventService.create_event(
                    name: body[:name],
                    location: body[:location],
                    start_time: body[:start_time],
                    end_time: body[:end_time],
                    description: body[:description]
                  )

                  response.status = 201
                  { message: 'Event created', event: event.to_api_hash }.to_json
                  
                rescue JSON::ParserError
                  response.status = 400
                  { error: 'Invalid JSON format' }.to_json
                rescue ArgumentError => e
                  response.status = 400
                  { error: e.message }.to_json
                end
              end
            end

            r.on 'attendances' do
              r.is String do |id|
                r.get do
                  record = TickIt::AttendanceRecordService.find_record(id)
                  if record
                    record.api_json_hash.to_json
                  else
                    response.status = 404
                    { error: 'Attendance record not found' }.to_json
                  end
                end
              end

              r.is do
                r.get do
                  { attendance_ids: TickIt::AttendanceRecordService.all_attendance_records }.to_json
                end

                r.post do
                  body = JSON.parse(r.body.read, symbolize_names: true)
                  allowed_keys = %i[student_id event_id timestamp location]
                  attempted_keys = body.keys
                  illegal_keys = attempted_keys - allowed_keys

                  if illegal_keys.any?
                    TickIt::SecurityLog.log_mass_assignment_warning(
                      'AttendanceRecord',
                      attempted_keys.map(&:to_s),
                      allowed_keys.map(&:to_s)
                    )
                    response.status = 400
                    return({ error: 'Illegal mass assignment detected' }.to_json)
                  end

                  record = TickIt::AttendanceRecordService.create_record(
                    student_id: body[:student_id],
                    event_id: body[:event_id],
                    timestamp: body[:timestamp]
                  )

                  response.status = 201
                  { message: 'Attendance successfully recorded', id: record.id }.to_json
                rescue JSON::ParserError
                  response.status = 400
                  { error: 'Invalid JSON format' }.to_json
                rescue ArgumentError => e
                  response.status = 400
                  { error: e.message }.to_json
                rescue StandardError => e
                  response.status = 404
                  { error: e.message }.to_json
                end
              end
            end

            r.on 'students' do
              r.is String, 'events' do |student_id|
                r.get do
                  records = TickIt::AttendanceRecordService.records_for_student(student_id)
                  event_ids = records.map { |record| record[:event_id] }.uniq
                  events = event_ids.filter_map do |event_id|
                    event = TickIt::EventService.find_event(event_id)
                    event&.to_api_hash
                  end

                  { student_id: student_id, events: events }.to_json
                end
              end

              r.is String, 'courses' do |student_id|
                r.get do
                  records = TickIt::AttendanceRecordService.records_for_student(student_id)
                  event_ids = records.map { |record| record[:event_id] }.uniq
                  courses = event_ids.filter_map do |event_id|
                    event = TickIt::EventService.find_event(event_id)
                    event&.to_api_hash
                  end

                  { student_id: student_id, courses: courses }.to_json
                end
              end
            end

            r.on 'accounts' do
              r.get String do |account_id|
                account = TickIt::AccountService.find_account(account_id)

                if account.nil?
                  response.status = 404
                  next({ error: 'Account not found' }.to_json)
                end

                response.status = 200
                {
                  account: {
                    id: account.id,
                    email: account.email,
                    role: account.role
                  }
                }.to_json
              end

              r.post do
                account_data = JSON.parse(r.body.read)

                account = TickIt::AccountService.create_account(
                  email: account_data['email'],
                  password: account_data['password'],
                  role: account_data['role'] || 'member'
                )

                response.status = 201
                {
                  message: 'Account created successfully',
                  account: { id: account.id, email: account.email, role: account.role }
                }.to_json
              rescue JSON::ParserError
                response.status = 400
                { error: 'Invalid JSON format' }.to_json
              rescue ArgumentError => e
                response.status = 400
                { error: e.message }.to_json
              rescue StandardError => e
                response.status = 400
                { error: e.message }.to_json
              end
            end
          end
        end

        response.status = 404
        { error: 'Route not found' }.to_json
      rescue StandardError => e
        TickIt::SecurityLog.log_error(e, path: r.path, method: r.request_method)
        response.status = 500
        { error: 'Internal server error' }.to_json
      end
    end
  end
end
