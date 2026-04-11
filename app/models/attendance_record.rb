# frozen_string_literal: true

module TickIt
  # Links a student to an event with check-in/out state
  class AttendanceRecord < Sequel::Model(TickIt::Api::DB[:attendance_records])
    plugin :timestamps, update_on_create: true

    many_to_one :student, class: 'TickIt::Student'
    many_to_one :event, class: 'TickIt::Event'

    # Primary key lookup for API routes (invalid or non-numeric id returns nil)
    def self.with_pk_string(id_str)
      pk = Integer(id_str.to_s, exception: false)
      return nil unless pk&.positive?

      with_pk(pk)
    end

    def api_json_hash
      {
        id: id,
        student_id: student.student_number,
        status: status,
        check_in_time: check_in_time&.iso8601,
        event_id: event_id
      }
    end
  end
end
