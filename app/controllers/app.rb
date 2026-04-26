# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../../lib/secure_db'
require_relative '../../lib/security_log'
require_relative '../models/event'
require_relative '../models/attendance_record'
require_relative '../models/account'
require_relative '../services/event_service'
require_relative '../services/account_service'
require_relative '../services/attendance_record_service'

module TickIt
  # The main TickIt API class that handles attendance record endpoints
  class Api < Roda
    plugin :halt

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

              r.is doService.find_event(id_str)
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
                  events = TickIt::EventService.all_events
                  { events: events }.to_json
                end

                r.post do
                  body = JSON.parse(r.body.read, symbolize_names: true)

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
                rescue Sequel::MassAssignmentRestriction => e
                  TickIt::SecurityLog.log_mass_assignment_warning('Event', body.keys.map(&:to_s), TickIt::Event.allowed_columns)
                  response.status = 400
                  { error: "Illegal mass assignment detected" }.to_json
                end
              end

                end
                end
    
              r.on 'accounts' do
                # GET /api/v1/accounts/:id
                r.get String do |account_id|
                  account = TickIt::AccountService.find_account(account_id)
                  
                  if account.nil?
                    response.status = 404
                    r.halt({ error: 'Account not found' }.to_json)
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
    
                # POST /api/v1/accounts
                r.post do
                  begin
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
                  end
                end
              end
            end