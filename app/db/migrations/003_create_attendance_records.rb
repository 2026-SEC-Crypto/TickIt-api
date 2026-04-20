# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :attendance_records do
      #primary_key :id
      String :id, type: :uuid, primary_key: true
      foreign_key :event_id, :events, type: :uuid, null: false
      foreign_key :student_id, :students, type: :uuid, null: false
      String :status, null: false, default: 'present'
      DateTime :check_in_time
      DateTime :check_out_time
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP

      index %i[student_id event_id]
    end
  end
end
