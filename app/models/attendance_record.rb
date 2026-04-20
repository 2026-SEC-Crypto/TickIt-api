# frozen_string_literal: true
require 'securerandom'
module TickIt
  # Links a student to an event with check-in/out state
  class AttendanceRecord < Sequel::Model(TickIt::Api::DB[:attendance_records])
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    #plugin :uuid
    set_allowed_columns :student_id, :event_id, :check_in_time

    many_to_one :student, class: 'TickIt::Student'
    many_to_one :event, class: 'TickIt::Event'
    def before_create
      self.id ||= SecureRandom.uuid
      super
    end
    # Primary key lookup for API routes (invalid or non-numeric id returns nil)
    def self.with_pk_string(id_str)
      with_pk(id_str)
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
