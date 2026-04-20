# frozen_string_literal: true
require 'securerandom'
module TickIt
  # Scheduled activity or session that students can attend
  class Event < Sequel::Model(TickIt::Api::DB[:events])
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    #plugin :uuid
    # Keep writable columns explicit to prevent mass assignment abuse.
    set_allowed_columns :name, :description, :location, :start_time, :end_time

    one_to_many :attendance_records, class: 'TickIt::AttendanceRecord'
    def before_create
      self.id ||= SecureRandom.uuid
      super
    end
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
