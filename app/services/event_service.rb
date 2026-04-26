# frozen_string_literal: true

require_relative '../models/event'
require_relative '../../lib/security_log'

module TickIt
  # Service object for managing Event resources
  class EventService
    # Parse JSON time values (ISO 8601 string or Unix timestamp)
    def self.parse_time(value)
      case value
      when Integer, Float then Time.at(value)
      when String then Time.iso8601(value)
      when Time then value
      else
        raise ArgumentError, 'Unsupported time format'
      end
    end

    # Retrieve all events
    def self.all_events
      Event.order(:id).map(&:to_api_hash)
    end

    # Retrieve a single event by ID
    def self.find_event(id)
      Event.with_pk(id.to_s)
    end

    # Create a new event with validation
    def self.create_event(name:, location:, start_time:, end_time:, description: nil)
      validate_event_params(name:, location:, start_time:, end_time:)

      start_t = parse_time(start_time)
      end_t = parse_time(end_time)

      Event.create(
        name: name.to_s.strip,
        location: location.to_s.strip,
        start_time: start_t,
        end_time: end_t,
        description: description&.to_s
      )
    rescue ArgumentError => e
      raise ArgumentError, "Invalid time format: #{e.message}"
    end

    # Update an existing event
    def self.update_event(event_id, **updates)
      event = find_event(event_id)
      raise "Event not found with id: #{event_id}" unless event

      # Parse time values if provided
      updates[:start_time] = parse_time(updates[:start_time]) if updates.key?(:start_time)
      updates[:end_time] = parse_time(updates[:end_time]) if updates.key?(:end_time)

      event.update(updates)
      event
    rescue ArgumentError => e
      raise ArgumentError, "Invalid time format: #{e.message}"
    end

    # Delete an event
    def self.delete_event(event_id)
      event = find_event(event_id)
      raise "Event not found with id: #{event_id}" unless event

      event.delete
    end

    private

    def self.validate_event_params(name:, location:, start_time:, end_time:)
      required = { name:, location:, start_time:, end_time: }
      missing = required.select do |key, val|
        val.nil? || (val.is_a?(String) && val.strip.empty?)
      end.keys

      raise ArgumentError, "Missing required fields: #{missing.join(', ')}" if missing.any?
    end
  end
end
