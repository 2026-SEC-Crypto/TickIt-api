# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('events') do |r|
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

          required = %i[name location start_time end_time]
          missing = required.select do |field|
            value = body[field]
            value.nil? || (value.is_a?(String) && value.strip.empty?)
          end

          if missing.any?
            response.status = 400
            return { error: 'Missing required fields', missing: missing.map(&:to_s) }.to_json
          end

          allowed_keys = %i[name location start_time end_time description]
          illegal_keys = body.keys - allowed_keys

          if illegal_keys.any?
            TickIt::SecurityLog.log_mass_assignment_warning(
              'Event',
              body.keys.map(&:to_s),
              allowed_keys.map(&:to_s)
            )
            response.status = 400
            return { error: 'Illegal mass assignment detected' }.to_json
          end

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
  end
end
