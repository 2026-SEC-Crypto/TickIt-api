# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('events') do |r|
      r.on String do |id_segment|
        id = id_segment.sub(/\.json\z/, '')
        account = account_from_token
        event = TickIt::EventService.find_event(id)

        if event.nil? || !TickIt::EventPolicy.new(account, event).can_view?
          response.status = 404
          next({ error: 'Event not found' }.to_json)
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

          policy = TickIt::EventPolicy.new(account, event)
          { event: event.to_api_hash, attendees: attendees, policy: policy.summary }.to_json
        end

        r.patch do
          unless TickIt::EventPolicy.new(account, event).can_update?
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
          unless TickIt::EventPolicy.new(account, event).can_delete?
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

          events = TickIt::EventPolicy::Scope.new(account).viewable.map(&:to_api_hash)
          { events: events }.to_json
        end

        r.post do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          unless TickIt::EventPolicy.new(account, nil).can_create?
            response.status = 403
            next({ error: 'Forbidden: insufficient permissions' }.to_json)
          end

          body = JSON.parse(r.body.read)
          form = TickIt::EventForm.new.call(body)

          unless form.success?
            response.status = 400
            next({ errors: form.errors.to_h }.to_json)
          end

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
  end
end
