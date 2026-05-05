# frozen_string_literal: true

require_relative '../models/account'
require_relative '../../lib/security_log'

module TickIt
  # Service object for managing user sessions
  class SessionService
    # Create a session for a logged-in user
    def self.create_session(account)
      {
        account_id: account.id,
        email: account.email,
        role: account.role,
        logged_in_at: Time.now
      }
    end

    # Validate session data
    def self.valid_session?(session_data)
      return false unless session_data
      return false unless session_data.is_a?(Hash)

      session_data.key?(:account_id) && session_data.key?(:email)
    end

    # Get current user from session
    def self.current_user(session_data)
      return nil unless valid_session?(session_data)

      Account.first(id: session_data[:account_id])
    end

    # Log user action
    def self.log_user_action(account_id, action)
      SecurityLog.log(
        user_id: account_id,
        action:,
        timestamp: Time.now
      )
    end
  end
end
