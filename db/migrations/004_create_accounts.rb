# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:accounts) do
      # Use UUIDs instead of auto-incrementing integers to prevent ID enumeration
      uuid :id, primary_key: true

      # PII Confidentiality: Store the symmetrically encrypted email
      String :secure_email, null: false

      # Searchability: Store the irreversible hash of the email for fast lookups
      # Making it unique ensures we don't have duplicate accounts
      String :email_hash, null: false, unique: true

      # Password Security: Store the salted and key-stretched password hash
      # Note: We don't need a separate 'salt' column because BCrypt embeds the salt into this hash string
      String :password_hash, null: false

      # Timestamps for record keeping
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
