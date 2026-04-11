# frozen_string_literal: true

module TickIt
  # Scheduled activity or session that students can attend
  class Event < Sequel::Model(TickIt::Api::DB[:events])
    plugin :timestamps, update_on_create: true

    one_to_many :attendance_records, class: 'TickIt::AttendanceRecord'

    def to_api_hash
      {
        id: id,
        name: name,
        location: location,
        start_time: start_time&.iso8601,
        end_time: end_time&.iso8601,
        description: description,
        created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601
      }
    end
  end
end
