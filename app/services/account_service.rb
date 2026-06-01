# frozen_string_literal: true

require 'digest'
require 'securerandom'
require_relative '../models/account'
require_relative '../models/event'
require_relative '../lib/security_log'
require_relative '../lib/auth_token'
require_relative '../lib/token_verifiable'

module TickIt
  # Service object for managing Account resources
  class AccountService
    extend TickIt::TokenVerifiable

    # Retrieve all accounts (only public information)
    def self.all_accounts
      Account.map { |acc| account_to_api_hash(acc) }
    end

    # Retrieve a single account by ID
    def self.find_account(id)
      Account.first(id: id.to_s)
    end

    # Create a new account with validation
    # Returns full API hash with auth token on success
    def self.create_account(email:, password:, role: 'regular', username: nil)
      validate_account_params(email:, password:)

      account = Account.create(
        email:,
        password:,
        role:,
        username: username&.to_s&.strip
      )

      # Return full API hash with auth token
      account_to_api_hash(account)
    rescue Sequel::UniqueConstraintViolation, SQLite3::ConstraintException
      raise "Account with email '#{email}' already exists"
    end

    # Authenticate account with password
    # Returns full API hash with auth token on success, nil on failure
    def self.authenticate(email:, password:)
      # Find account by email hash for security
      account = find_by_email(email)
      return nil unless account
      return nil unless account.password?(password)

      # Return full API hash with auth token
      account_to_api_hash(account)
    end

    # Find account by email
    def self.find_by_email(email)
      email_hash = Digest::SHA256.hexdigest(email)
      Account.first(email_hash:)
    end

    def self.find_or_create_sso_account(provider:, sub:, email:, username: nil, avatar_url: nil)
      account = Account.first(sso_provider: provider, sso_sub: sub)
      return account_to_api_hash(account) if account

      account = find_by_email(email)
      if account
        account.update(
          sso_provider: provider,
          sso_sub: sub,
          avatar_url: avatar_url,
          username: account.username || username
        )
        return account_to_api_hash(account)
      end

      generated_password = SecureRandom.hex(32)
      account = Account.create(
        email: email,
        password: generated_password,
        role: 'regular',
        username: username,
        sso_provider: provider,
        sso_sub: sub,
        avatar_url: avatar_url
      )

      account_to_api_hash(account)
    rescue Sequel::UniqueConstraintViolation, SQLite3::ConstraintException
      account = find_by_email(email)
      account ? account_to_api_hash(account) : (raise 'Unable to create SSO account')
    end

    # Update account (limited fields to prevent mass assignment)
    def self.update_account(account_id, **updates)
      account = find_account(account_id)
      raise "Account not found with id: #{account_id}" unless account

      # Only allow safe updates
      safe_updates = {}
      safe_updates[:role] = updates[:role] if updates.key?(:role) && valid_role?(updates[:role])
      safe_updates[:password] = updates[:password] if updates.key?(:password)

      account.update(safe_updates) if safe_updates.any?
      account
    end

    # Retrieve account by username, enforcing token scope and policy.
    # Returns account hash with api_key included when viewing own account.
    # Raises TokenVerifiable::Unauthorized or TokenVerifiable::Forbidden on access failure.
    def self.find_account_by_username(username, token:)
      account, scope = extract_auth(token)
      raise TokenVerifiable::Forbidden, 'Insufficient scope' unless scope.can?('read', 'accounts')

      target = Account.first(username: username)
      raise TokenVerifiable::Forbidden unless target && AccountPolicy.new(account, target, scope: scope).can_view?

      result = { id: target.id, username: target.username, email: target.email, role: target.role }
      result[:api_key] = generate_api_key(target) if account.id == target.id
      result
    end

    # Delete an account
    def self.delete_account(account_id)
      account = find_account(account_id)
      raise "Account not found with id: #{account_id}" unless account

      account.delete
    end

    # Add account as collaborator to an event
    def self.add_collaborator(account_id, event_id)
      account = find_account(account_id)
      raise "Account not found with id: #{account_id}" unless account

      event = Event.with_pk(event_id.to_s)
      raise "Event not found with id: #{event_id}" unless event

      account.add_collaborated_event(event) unless account.collaborated_events.include?(event)
      account
    end

    # Remove account as collaborator from an event
    def self.remove_collaborator(account_id, event_id)
      account = find_account(account_id)
      raise "Account not found with id: #{account_id}" unless account

      event = Event.with_pk(event_id.to_s)
      raise "Event not found with id: #{event_id}" unless event

      account.remove_collaborated_event(event)
      account
    end

    private

    def self.validate_account_params(email:, password:)
      raise ArgumentError, 'Email cannot be empty' if email.nil? || (email.is_a?(String) && email.strip.empty?)
      if password.nil? || (password.is_a?(String) && password.strip.empty?)
        raise ArgumentError,
              'Password cannot be empty'
      end
      raise 'Invalid email format' unless valid_email?(email)
    end

    def self.valid_email?(email)
      email.is_a?(String) && email.include?('@')
    end

    def self.valid_role?(role)
      %w[regular admin teacher].include?(role)
    end

    def self.account_to_api_hash(account)
      auth_token = AuthToken.generate(
        account_id: account.id,
        email: account.email,
        role: account.role,
        scope: AuthScope::FULL_ACCESS
      )

      {
        id: account.id,
        username: account.username,
        email: account.email,
        role: account.role,
        avatar_url: account.respond_to?(:avatar_url) ? account.avatar_url : nil,
        auth_token: auth_token
      }
    end

    def self.generate_api_key(account)
      AuthToken.generate(
        account_id: account.id,
        email: account.email,
        role: account.role,
        scope: AuthScope::READ_ONLY,
        expiry_hours: AuthToken::API_KEY_EXPIRY_HOURS
      )
    end
  end
end
