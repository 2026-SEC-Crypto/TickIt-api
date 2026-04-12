# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../models/student'
require_relative '../models/event'
require_relative '../models/attendance_record'

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
      r.root do # alive
        { message: 'TickIt API is up and running!' }.to_json
      end
      # /api/v1/...
      r.on 'api' do
        r.on 'v1' do
          r.on 'students' do
            r.is String do |id_segment|
              r.get do
                id_str = id_segment.sub(/\.json\z/, '')
                pk = Integer(id_str, exception: false)
                student = pk&.positive? && TickIt::Student.with_pk(pk)
                if student
                  { student: student.to_api_hash }.to_json
                else
                  response.status = 404
                  { error: 'Student not found' }.to_json
                end
              end
            end

            r.is do
              r.get do
                students = TickIt::Student.order(:id).map(&:to_api_hash)
                { students: students }.to_json
              end

              r.post do
                body = JSON.parse(r.body.read, symbolize_names: true)
                required = %i[name email student_number]
                missing = required.select do |key|
                  val = body[key]
                  val.nil? || (val.is_a?(String) && val.strip.empty?)
                end
                if missing.any?
                  response.status = 400
                  next(
                    {
                      error: 'Missing required fields',
                      missing: missing.map(&:to_s)
                    }.to_json
                  )
                end

                student = TickIt::Student.create(
                  name: body[:name].to_s.strip,
                  email: body[:email].to_s.strip,
                  student_number: body[:student_number].to_s.strip
                )

                response.status = 201
                { message: 'Student created', student: student.to_api_hash }.to_json
              rescue JSON::ParserError
                response.status = 400
                { error: 'Invalid JSON format' }.to_json
              rescue Sequel::UniqueConstraintViolation
                response.status = 400
                { error: 'Duplicate email or student_number' }.to_json
              end
            end
          end

          r.on 'events' do
            r.is String do |id_segment|
              r.get do
                id_str = id_segment.sub(/\.json\z/, '')
                pk = Integer(id_str, exception: false)
                event = pk&.positive? && TickIt::Event.with_pk(pk)
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
                  next(
                    {
                      error: 'Missing required fields',
                      missing: missing.map(&:to_s)
                    }.to_json
                  )
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
              rescue ArgumentError
                response.status = 400
                { error: 'Invalid start_time or end_time' }.to_json
              end
            end
          end

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

                student = TickIt::Student.first(student_number: request_body[:student_id].to_s)
                unless student
                  response.status = 404
                  next({ error: 'Student not found' }.to_json)
                end

                event =
                  if request_body[:event_id]
                    TickIt::Event.with_pk(Integer(request_body[:event_id], exception: false))
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
                  student_id: student.id,
                  event_id: event.id,
                  status: request_body[:status] || 'present',
                  check_in_time: check_in
                )

                response.status = 201
                { message: 'Attendance successfully recorded', id: new_record.id }.to_json
              rescue JSON::ParserError # failed
                response.status = 400
                { error: 'Invalid JSON format' }.to_json
              end
            end
          end
        end
      end
    end
  end
end
