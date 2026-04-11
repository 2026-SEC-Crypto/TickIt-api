# frozen_string_literal: true

module TickIt
  # Student enrolled in the system (check-in identity)
  class Student < Sequel::Model(TickIt::Api::DB[:students])
    plugin :timestamps, update_on_create: true

    one_to_many :attendance_records, class: 'TickIt::AttendanceRecord'
  end
end
