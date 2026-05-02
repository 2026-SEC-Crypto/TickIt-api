# frozen_string_literal: true

require_relative '../models/attendance_record'
require_relative '../models/event'
require_relative '../../lib/security_log'

module TickIt
  # Service object for managing AttendanceRecord resources
  class AttendanceRecordService
    # Retrieve all attendance records (returns IDs only for large datasets)
    def self.all_attendance_records
      AttendanceRecord.order(:id).select_map(:id)
    end

    # Retrieve all attendance records with full details
    def self.all_attendance_records_detailed
      AttendanceRecord.order(:id).map(&:api_json_hash)
    end

    # Retrieve a single attendance record by ID
    def self.find_record(id)
      AttendanceRecord.with_pk_string(id.to_s)
    end

    # Create a new attendance record
    def self.create_record(student_id:, event_id: nil, timestamp: nil)
      validate_student_id(student_id)

      # Find or use the first available event
      event = if event_id
                Event.with_pk(event_id.to_s)
              else
                Event.order(:id).first
              end

      raise 'No event available; create an event or pass event_id' unless event

      check_in = if timestamp
                   parse_timestamp(timestamp)
                 else
                   Time.now
                 end

      AttendanceRecord.create(
        student_number: student_id.to_s,
        event_id: event.id,
        check_in_time: check_in
      )
    rescue ArgumentError => e
      raise ArgumentError, "Invalid timestamp format: #{e.message}"
    rescue Sequel::MassAssignmentRestriction => e
      TickIt::SecurityLog.log_mass_assignment_warning(
        'AttendanceRecord',
        [],
        AttendanceRecord.allowed_columns
      )
      raise "Mass assignment prevented: #{e.message}"
    end

    # Update attendance record (check-in/out times)
    def self.update_record(record_id, check_out_time: nil)
      record = find_record(record_id)
      raise "Attendance record not found with id: #{record_id}" unless record

      updates = {}
      updates[:check_out_time] = parse_timestamp(check_out_time) if check_out_time

      record.update(updates) if updates.any?
      record
    rescue ArgumentError => e
      raise ArgumentError, "Invalid timestamp format: #{e.message}"
    end

    # Get attendance records for a specific event
    def self.records_for_event(event_id)
      event = Event.with_pk(event_id.to_s)
      raise "Event not found with id: #{event_id}" unless event

      event.attendance_records.map(&:api_json_hash)
    end

    # Get attendance records for a specific student
    def self.records_for_student(student_id)
      AttendanceRecord
        .where(student_number: student_id.to_s)
        .map(&:api_json_hash)
    end

    # Delete an attendance record
    def self.delete_record(record_id)
      record = find_record(record_id)
      raise "Attendance record not found with id: #{record_id}" unless record

      record.delete
    end

    private

    def self.validate_student_id(student_id)
      return unless student_id.nil? || (student_id.is_a?(String) && student_id.strip.empty?)

      raise ArgumentError,
            'Student ID cannot be empty'
    end

    def self.parse_timestamp(value)
      case value
      when Integer, Float then Time.at(value)
      when String then Time.iso8601(value)
      when Time then value
      else
        raise ArgumentError, 'Unsupported timestamp format'
      end
    end
  end
end
