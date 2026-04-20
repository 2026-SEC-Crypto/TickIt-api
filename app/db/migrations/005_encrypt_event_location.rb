# frozen_string_literal: true

Sequel.migration do
  change do
    # Rename location column to indicate it's encrypted
    rename_column :events, :location, :secure_location
  end
end
