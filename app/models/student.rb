# frozen_string_literal: true

module TickIt
  # Student enrolled in the system (check-in identity)
  class Student < Sequel::Model(TickIt::Api::DB[:students])
    plugin :timestamps, update_on_create: true

    one_to_many :attendance_records, class: 'TickIt::AttendanceRecord'

    def to_api_hash
      {
        id: id,
        name: name,
        email: email,
        student_number: student_number,
        created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601
      }
    end
  end
end
