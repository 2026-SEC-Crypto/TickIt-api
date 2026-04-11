# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :attendance_records do
      primary_key :id
      foreign_key :student_id, :students, null: false
      foreign_key :event_id, :events, null: false
      String :status, null: false, default: 'present'
      DateTime :check_in_time
      DateTime :check_out_time
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
      
      index [:student_id, :event_id]
    end
  end
end
