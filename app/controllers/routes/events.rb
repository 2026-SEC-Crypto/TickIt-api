# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('events') do |r|
      # Series routes must come before r.on String to avoid being captured
      r.on 'series' do
        r.on String do |series_id|
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          series_events = TickIt::Event.where(series_id: series_id).order(:start_time).all

          if series_events.empty?
            response.status = 404
            next({ error: 'Series not found' }.to_json)
          end

          unless TickIt::EventPolicy.new(account, series_events.first, scope: scope_from_token).can_update?
            response.status = 403
            next({ error: 'Forbidden: insufficient permissions' }.to_json)
          end

          r.patch do
            body = JSON.parse(r.body.read)

            # Use first event's start_time as reference to compute attendance offsets
            ref = series_events.first
            att_start_offset = if body['attendance_start_time']
              TickIt::EventService.parse_time(body['attendance_start_time']) - ref.start_time
            end
            att_end_offset = if body['attendance_end_time']
              TickIt::EventService.parse_time(body['attendance_end_time']) - ref.start_time
            end

            series_events.each do |ev|
              updates = {}
              updates[:name]        = body['name']        if body.key?('name')
              updates[:location]    = body['location']    if body.key?('location')
              updates[:description] = body['description'] if body.key?('description')
              updates[:attendance_start_time] = ev.start_time + att_start_offset if att_start_offset
              updates[:attendance_end_time]   = ev.start_time + att_end_offset   if att_end_offset
              ev.update(updates) unless updates.empty?
            end

            { message: "Updated #{series_events.size} events", series_id: series_id }.to_json
          rescue JSON::ParserError
            response.status = 400
            { error: 'Invalid JSON format' }.to_json
          rescue ArgumentError => e
            response.status = 400
            { error: e.message }.to_json
          end

          r.delete do
            unless TickIt::EventPolicy.new(account, series_events.first, scope: scope_from_token).can_delete?
              response.status = 403
              next({ error: 'Forbidden: insufficient permissions' }.to_json)
            end

            count = series_events.size
            series_events.each do |ev|
              ev.remove_all_collaborators
              ev.destroy
            end
            { message: "Deleted #{count} events" }.to_json
          end
        end
      end

      r.on String do |id_segment|
        id = id_segment.sub(/\.json\z/, '')
        account = account_from_token
        event = TickIt::EventService.find_event(id)

        if event.nil? || !TickIt::EventPolicy.new(account, event, scope: scope_from_token).can_view?
          response.status = 404
          next({ error: 'Event not found' }.to_json)
        end

        r.post 'start_attendance' do
          unless TickIt::EventPolicy.new(account, event, scope: scope_from_token).can_update?
            response.status = 403
            next({ error: 'Forbidden: only event teachers or admins can start attendance' }.to_json)
          end

          now       = Time.now
          att_start = event.attendance_start_time
          att_end   = event.attendance_end_time

          if att_start.nil? || att_end.nil?
            response.status = 422
            next({ error: 'This event has no attendance window configured' }.to_json)
          end

          unless now >= att_start && now <= att_end
            response.status = 422
            next({ error: "Outside attendance window (#{att_start.iso8601} – #{att_end.iso8601})" }.to_json)
          end

          token = TickIt::AttendanceToken.generate(event_id: event.id)

          proto    = request.env.fetch('HTTP_X_FORWARDED_PROTO', request.scheme)
          base_url = "#{proto}://#{request.env['HTTP_HOST']}"
          scan_url = TickIt::AttendanceToken.scan_url(token, base_url: base_url)

          {
            token:      token,
            scan_url:   scan_url,
            expires_in: TickIt::AttendanceToken::DEFAULT_EXPIRY_SECONDS,
            event:      { id: event.id, name: event.name }
          }.to_json
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        end

        r.get do
          attendees = TickIt::AttendanceRecord
            .where(event_id: event.id)
            .map do |rec|
              acct = TickIt::Account.first(id: rec.student_number.to_s)
              {
                username: acct&.username,
                email: acct&.email,
                check_in_time: rec.check_in_time&.iso8601
              }
            end

          policy = TickIt::EventPolicy.new(account, event, scope: scope_from_token)
          { event: event.to_api_hash, attendees: attendees, policy: policy.summary }.to_json
        end

        r.patch do
          unless TickIt::EventPolicy.new(account, event, scope: scope_from_token).can_update?
            response.status = 403
            next({ error: 'Forbidden: insufficient permissions' }.to_json)
          end

          body = JSON.parse(r.body.read)
          now = Time.now
          event_started = event.start_time && now >= event.start_time
          event_ended   = event.end_time   && now >= event.end_time

          if event_ended
            allowed = %w[description attendance_start_time attendance_end_time]
            body = body.select { |k, _| allowed.include?(k) }
          elsif event_started
            body.delete('start_time')
          end

          updates = {}
          updates[:name]                  = body['name']                  if body.key?('name')
          updates[:location]              = body['location']              if body.key?('location')
          updates[:description]           = body['description']           if body.key?('description')
          updates[:start_time]            = TickIt::EventService.parse_time(body['start_time'])            if body.key?('start_time')
          updates[:end_time]              = TickIt::EventService.parse_time(body['end_time'])              if body.key?('end_time')
          updates[:attendance_start_time] = TickIt::EventService.parse_time(body['attendance_start_time']) if body.key?('attendance_start_time') && body['attendance_start_time']
          updates[:attendance_end_time]   = TickIt::EventService.parse_time(body['attendance_end_time'])   if body.key?('attendance_end_time') && body['attendance_end_time']

          event.update(updates) unless updates.empty?
          { event: event.reload.to_api_hash }.to_json
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        rescue ArgumentError => e
          response.status = 400
          { error: e.message }.to_json
        end

        r.delete do
          unless TickIt::EventPolicy.new(account, event, scope: scope_from_token).can_delete?
            response.status = 403
            next({ error: 'Forbidden: insufficient permissions' }.to_json)
          end

          event.remove_all_collaborators
          event.destroy
          response.status = 200
          { message: 'Event deleted successfully' }.to_json
        end
      end

      r.is do
        r.get do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          created_ids = TickIt::DB[:accounts_events]
            .where(account_id: account.id.to_s)
            .select_map(:event_id)

          scope = r.params['mine'] == 'true' ? TickIt::EventPolicy::Scope.new(account).viewable : TickIt::Event.order(:start_time).all

          events = scope.map do |e|
            e.to_api_hash.merge(created_by_me: created_ids.include?(e.id.to_s))
          end
          { events: events }.to_json
        end

        r.post do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          unless TickIt::EventPolicy.new(account, nil, scope: scope_from_token).can_create?
            response.status = 403
            next({ error: 'Forbidden: insufficient permissions' }.to_json)
          end

          body = JSON.parse(r.body.read)
          verified_data = TickIt::SignedRequest.verify(body)
          form = TickIt::EventForm.new.call(verified_data)

          unless form.success?
            response.status = 400
            next({ errors: form.errors.to_h }.to_json)
          end

          repeat_weeks = form.values[:repeat_weeks].to_i

          result = TickIt::DB.transaction do
            if repeat_weeks >= 2
              events = TickIt::EventService.create_recurring_events(
                name: form.values[:name],
                location: form.values[:location],
                start_time: form.values[:start_time],
                end_time: form.values[:end_time],
                attendance_start_time: form.values[:attendance_start_time],
                attendance_end_time: form.values[:attendance_end_time],
                description: form.values[:description],
                repeat_weeks: repeat_weeks
              )
              events.each { |ev| ev.add_collaborator(account) }
              { type: :recurring, events: events }
            else
              event = TickIt::EventService.create_event(
                name: form.values[:name],
                location: form.values[:location],
                start_time: form.values[:start_time],
                end_time: form.values[:end_time],
                attendance_start_time: form.values[:attendance_start_time],
                attendance_end_time: form.values[:attendance_end_time],
                description: form.values[:description]
              )
              event.add_collaborator(account)
              { type: :single, event: event }
            end
          end

          response.status = 201
          if result[:type] == :recurring
            events = result[:events]
            { message: "#{repeat_weeks} recurring events created",
              events: events.map(&:to_api_hash),
              series_id: events.first.series_id }.to_json
          else
            { message: 'Event created', event: result[:event].to_api_hash }.to_json
          end
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        rescue ArgumentError => e
          response.status = 400
          { error: e.message }.to_json
        end
        rescue TickIt::SignedRequest::InvalidSignature
          response.status = 401
          { error: 'Invalid request signature' }.to_json
      end
    end
  end
end
