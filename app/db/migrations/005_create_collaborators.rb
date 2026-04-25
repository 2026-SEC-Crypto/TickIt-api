# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:accounts_events) do
      # Primary key is the combination of both foreign keys
      primary_key %i[account_id event_id]

      # Foreign key to accounts table.
      # on_delete: :cascade ensures that if an account is deleted, their collaboration records vanish too
      foreign_key :account_id, :accounts, type: :uuid, null: false, on_delete: :cascade

      # Foreign key to events table.
      foreign_key :event_id, :events, type: :uuid, null: false, on_delete: :cascade

      index %i[account_id event_id]
    end
  end
end
