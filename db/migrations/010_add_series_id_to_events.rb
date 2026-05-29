# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:events) do
      add_column :series_id, String
      add_index :series_id
    end
  end
end
