# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('events') do |r|
      r.is String do |id_segment|
        r.get do
          id = id_segment.sub(/\.json\z/, '')
          account = account_from_token
          event = TickIt::EventService.find_event(id)

          if event.nil? || !TickIt::EventPolicy.new(account, event).can_view?
            response.status = 404
            next({ error: 'Event not found' }.to_json)
          end

          { event: event.to_api_hash }.to_json
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
            description: form.values[:description]
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
  end
end
