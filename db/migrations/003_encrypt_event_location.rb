# frozen_string_literal: true

Sequel.migration do
  change do
    rename_column :events, :location, :secure_location

    add_column :events, :location_hash, String
  end
end
