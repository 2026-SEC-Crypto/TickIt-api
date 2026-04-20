# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :events do
      #primary_key :id
      String :id, type: :uuid, primary_key: true
      String :name, null: false
      String :location, null: false
      DateTime :start_time, null: false
      DateTime :end_time, null: false
      String :description
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
