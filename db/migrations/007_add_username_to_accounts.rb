# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :username, String
    end
  end
end
