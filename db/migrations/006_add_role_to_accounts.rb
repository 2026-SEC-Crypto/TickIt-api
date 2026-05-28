# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:accounts) do
      # Add a 'role' column to identify the user's privilege level
      # Default to 'member' so new signups don't automatically get admin rights
      add_column :role, String, default: 'member'
    end
  end
end
