# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:teacher_applications) do
      uuid :id, primary_key: true
      uuid :account_id, null: false, foreign_key: true, table: :accounts
      String :status, null: false, default: 'pending'
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
