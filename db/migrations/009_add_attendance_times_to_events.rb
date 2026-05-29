# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:events) do
      add_column :attendance_start_time, DateTime
      add_column :attendance_end_time, DateTime
    end
  end
end
