# frozen_string_literal: true

Sequel.migration do
  change do
    # Add hash lookup columns for encrypted fields
    # These allow uniqueness constraints and efficient lookups
    add_column :students, :email_hash, String, unique: true, null: false, default: ''
    add_column :students, :student_number_hash, String, unique: true, null: false, default: ''
    
    add_column :events, :location_hash, String, null: true
  end
end
