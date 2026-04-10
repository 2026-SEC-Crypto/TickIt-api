# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../models/attendance_record'

module TickIt
  # The main TickIt API class that handles attendance record endpoints
  class Api < Roda
    plugin :halt
    route do |r|
      response['Content-Type'] = 'application/json' # set default format
      r.root do # alive
        { message: 'TickIt API is up and running!' }.to_json
      end
      # /api/v1/attendances
      r.on 'api' do
        r.on 'v1' do
          r.on 'attendances' do
            r.is String do |id_with_ext| # get by id
              r.get do
                id = id_with_ext.sub('.json', '')
                record = TickIt::AttendanceRecord.find(id)
                if record
                  record.to_json
                else
                  response.status = 404 # not found
                  { error: 'Attendance record not found' }.to_json
                end
              end
            end

            r.is do
              r.get do # get all
                records = TickIt::AttendanceRecord.all
                { attendance_ids: records }.to_json
              end

              r.post do # create new record
                # read
                request_body = JSON.parse(r.body.read, symbolize_names: true)

                # create and save
                new_record = TickIt::AttendanceRecord.new(request_body)
                new_record.save

                # success
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
