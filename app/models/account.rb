# frozen_string_literal: true

require 'sequel'
require 'digest' # Needed for SHA256 hashing
require_relative '../../lib/key_stretching'
require_relative '../../lib/secure_db' # Use your existing encryption tool

module TickIt
  # Account model to manage user authentication and secure details
  class Account < Sequel::Model
    plugin :uuid, field: :id
    plugin :association_dependencies

    # Many-to-Many relationship with Event
    # An account can collaborate on multiple events
    many_to_many :collaborated_events,
                 class: :'TickIt::Event',
                 join_table: :accounts_events,
                 left_key: :account_id,
                 right_key: :event_id

    # If an account is deleted, :nullify will only remove the links in the join table (accounts_events),
    # but it WILL NOT destroy the actual events they collaborated on.
    add_association_dependencies collaborated_events: :nullify

    # ---------------------------------------------------------
    # 1. Password Security (Key-stretching & Hashing)
    # ---------------------------------------------------------

    # Setter: Encrypts the plain text password and saves the hash securely
    def password=(new_password)
      self.password_hash = KeyStretching.password_hash(new_password)
    end

    # Checker: Verifies if the provided password matches the stored hash
    def password?(try_password)
      KeyStretching.password?(try_password, password_hash)
    end

    # Explicitly prevent reading the password (not get!)
    def password
      nil # Never return the password or the hash directly
    end

    # ---------------------------------------------------------
    # 2. PII Confidentiality & Searchability (Email)
    # ---------------------------------------------------------

    # Setter: Encrypts the email and generates a deterministic hash for searching
    def email=(plain_email)
      # Encrypt the email for privacy (reversible with the correct key)
      self.secure_email = SecureDB.encrypt(plain_email)

      # Hash the email for fast lookups in the database (irreversible)
      # Using SHA256 ensures the same email always produces the same hash
      self.email_hash = Digest::SHA256.hexdigest(plain_email)
    end

    # Getter: Decrypts the secure_email back to plain text when needed in the app
    def email
      SecureDB.decrypt(secure_email)
    end
  end
end
