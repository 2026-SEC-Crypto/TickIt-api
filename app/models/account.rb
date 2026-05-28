# frozen_string_literal: true

require 'sequel'
require 'digest' # Needed for SHA256 hashing
require_relative '../lib/key_stretching'
require_relative '../lib/secure_db'

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

    # ---------------------------------------------------------
    # 3. Roles & Permissions
    # ---------------------------------------------------------

    # Checks if the account has administrative privileges
    def admin?
      role == 'admin'
    end

    # Checks if the account is a regular member
    def member?
      role == 'member'
    end

    # (Optional) Checks if the user is an organizer (just as an example for "other roles")
    def organizer?
      role == 'organizer'
    end

    # ---------------------------------------------------------
    # 4. System-Level Capabilities
    # ---------------------------------------------------------

    # Returns a comprehensive hash of system-level privileges for this account
    # Defines what this account can do across the system based on its role
    # @return [Hash] System capabilities organized by resource type and action
    def capabilities # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      {
        system_privileges: {
          is_admin: admin?,
          is_organizer: organizer?,
          is_member: member?,
          role: role
        },
        account_management: {
          view_own_profile: true,
          update_own_profile: true,
          delete_own_account: true,
          view_all_accounts: admin?,
          create_accounts: admin?,
          update_any_account: admin?,
          delete_any_account: admin?
        },
        event_management: {
          view_all_events: ['member', 'admin', 'organizer'].include?(role), # rubocop:disable Style/WordArray
          create_events: ['admin', 'organizer'].include?(role), # rubocop:disable Style/WordArray
          update_own_events: ['admin', 'organizer'].include?(role), # rubocop:disable Style/WordArray
          update_any_events: admin?,
          delete_own_events: ['admin', 'organizer'].include?(role), # rubocop:disable Style/WordArray
          delete_any_events: admin?
        },
        attendance_management: {
          view_own_attendance: true,
          view_all_attendance: ['admin', 'organizer'].include?(role), # rubocop:disable Style/WordArray
          record_attendance: ['admin', 'organizer'].include?(role), # rubocop:disable Style/WordArray
          edit_attendance: ['admin', 'organizer'].include?(role), # rubocop:disable Style/WordArray
          delete_attendance: admin?
        },
        collaboration: {
          can_collaborate_on_events: ['member', 'admin', 'organizer'].include?(role) # rubocop:disable Style/WordArray
        }
      }
    end
  end
end
