# frozen_string_literal: true

require_relative '../models/account'
require_relative '../../lib/security_log'

module TickIt
  # Session management service
  # Handles creation, validation, and retrieval of user sessions
  # Sessions are stored as encrypted HTTP-only cookies by Roda's session plugin
  class SessionService
    # Create a session hash for a logged-in user
    # Called after successful authentication to populate session data
    # Session data is automatically encrypted by Roda and stored in HTTP-only cookie
    def self.create_session(account)
      {
        account_id: account.id,
        email: account.email,
        role: account.role,
        logged_in_at: Time.now
      }
    end

    # Validate that session contains required user identification data
    # Returns true only if session has both account_id and email
    def self.valid_session?(session_data)
      return false unless session_data
      return false unless session_data.is_a?(Hash)

      session_data.key?(:account_id) && session_data.key?(:email)
    end

    # Retrieve the current logged-in user from session data
    # Validates session and fetches account from database
    # Returns nil if session is invalid or account no longer exists
    # This ensures logged-out users or deleted accounts cannot access protected pages
    def self.current_user(session_data)
      return nil unless valid_session?(session_data)

      Account.first(id: session_data[:account_id])
    end

    # Log user authentication actions to security log
    # Records login, logout, and register events for audit trail
    def self.log_user_action(account_id, action)
      SecurityLog.log(
        user_id: account_id,
        action:,
        timestamp: Time.now
      )
    end
  end
end
