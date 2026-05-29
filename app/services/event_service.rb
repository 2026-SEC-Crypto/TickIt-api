# frozen_string_literal: true

require_relative '../models/event'
require_relative '../lib/security_log'

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

    # Retrieve events where the given account is a collaborator
    def self.events_for_account(account_id)
      Event
        .join(:accounts_events, event_id: :id)
        .where(Sequel[:accounts_events][:account_id] => account_id.to_s)
        .order(Sequel[:events][:id])
        .map(&:to_api_hash)
    end

    # Retrieve a single event by ID
    def self.find_event(id)
      Event.with_pk(id.to_s)
    end

    # Create a new event with validation
    def self.create_event(name:, location:, start_time:, end_time:, description: nil,
                          attendance_start_time: nil, attendance_end_time: nil, series_id: nil)
      validate_event_params(name:, location:, start_time:, end_time:)

      start_t = parse_time(start_time)
      end_t = parse_time(end_time)
      att_start = attendance_start_time ? parse_time(attendance_start_time) : nil
      att_end = attendance_end_time ? parse_time(attendance_end_time) : nil

      Event.create(
        name: name.to_s.strip,
        location: location.to_s.strip,
        start_time: start_t,
        end_time: end_t,
        attendance_start_time: att_start,
        attendance_end_time: att_end,
        description: description&.to_s,
        series_id: series_id
      )
    rescue ArgumentError => e
      raise ArgumentError, "Invalid time format: #{e.message}"
    end

    # Batch-create weekly recurring events
    def self.create_recurring_events(name:, location:, start_time:, end_time:, repeat_weeks:,
                                     description: nil, attendance_start_time: nil, attendance_end_time: nil)
      validate_event_params(name:, location:, start_time:, end_time:)

      start_t   = parse_time(start_time)
      end_t     = parse_time(end_time)
      duration  = end_t - start_t
      att_start = attendance_start_time ? parse_time(attendance_start_time) : nil
      att_end   = attendance_end_time   ? parse_time(attendance_end_time)   : nil
      att_start_offset = att_start ? att_start - start_t : nil
      att_end_offset   = att_end   ? att_end   - start_t : nil

      week_secs = 7 * 24 * 3600
      sid = SecureRandom.uuid

      repeat_weeks.times.map do |i|
        s = start_t + (i * week_secs)
        e = s + duration
        Event.create(
          name: name.to_s.strip,
          location: location.to_s.strip,
          start_time: s,
          end_time: e,
          attendance_start_time: att_start_offset ? s + att_start_offset : nil,
          attendance_end_time:   att_end_offset   ? s + att_end_offset   : nil,
          description: description&.to_s,
          series_id: sid
        )
      end
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
