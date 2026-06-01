# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:accounts) do
      # SSO support: Store the OAuth provider name (e.g., 'google')
      add_column :sso_provider, String, null: true

      # SSO support: Store the unique subject identifier from the OAuth provider
      # Combined with provider, this uniquely identifies the user at the provider
      add_column :sso_sub, String, null: true

      # User profile: Store avatar/profile picture URL from provider
      add_column :avatar_url, String, null: true

      # Index for faster SSO lookups
      add_index [:sso_provider, :sso_sub], unique: true, where: 'sso_provider IS NOT NULL'
    end
  end
end
