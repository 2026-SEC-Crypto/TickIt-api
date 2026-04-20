# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :students do
      #primary_key :id
      String :id, type: :uuid, primary_key: true
      String :name, null: false
      String :email, null: false, unique: true
      String :student_number, null: false, unique: true
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
