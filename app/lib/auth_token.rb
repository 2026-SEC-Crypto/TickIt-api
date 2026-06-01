# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'securable'
require_relative 'auth_scope'

module TickIt
  # AuthToken library for creating, validating, and verifying authentication tokens
  # Tokens contain encrypted account information with expiration timestamps
  # Uses Securable for encryption/decryption
  class AuthToken
    TOKEN_EXPIRY_HOURS = 24 # Tokens valid for 24 hours

    # Generate a new authentication token for an account
    # @param account_id [String] unique identifier for the account
    # @param email [String] account email address
    # @param role [String] account role (member, organizer, admin)
    # @return [String] encrypted token containing account data and expiration
    API_KEY_EXPIRY_HOURS = 24 * 365 # API keys valid for 1 year

    def self.generate(account_id:, email:, role:, scope: AuthScope::FULL_ACCESS, expiry_hours: TOKEN_EXPIRY_HOURS)
      payload = {
        account_id: account_id,
        email: email,
        role: role,
        scope: scope,
        issued_at: Time.now.to_i,
        expires_at: (Time.now + (expiry_hours * 3600)).to_i
      }

      # Encrypt the JSON payload
      plaintext = payload.to_json
      Securable.encrypt(plaintext)
    end

    # Verify and decrypt a token, returning the payload if valid
    # @param token [String] encrypted token to verify
    # @return [Hash] decrypted token payload with keys: account_id, email, role, issued_at, expires_at
    # @raise [StandardError] if token is invalid or expired
    def self.verify(token)
      return nil if token.nil? || token.strip.empty?

      begin
        # Decrypt the token
        plaintext = Securable.decrypt(token)
        payload = JSON.parse(plaintext, symbolize_names: true)

        # Check if token has expired
        if payload[:expires_at] < Time.now.to_i
          raise "Token has expired. Expires at: #{Time.at(payload[:expires_at])}"
        end

        payload
      rescue JSON::ParserError => e
        raise "Invalid token format: #{e.message}"
      rescue StandardError => e
        raise "Token verification failed: #{e.message}"
      end
    end

    # Extract Bearer token from Authorization header
    # @param auth_header [String] HTTP Authorization header value (e.g., "Bearer <TOKEN>")
    # @return [String] token without "Bearer" prefix, or nil if invalid format
    def self.extract_from_header(auth_header)
      return nil if auth_header.nil? || auth_header.strip.empty?

      if auth_header.start_with?('Bearer ')
        auth_header.sub('Bearer ', '').strip
      else
        nil
      end
    end

    # Check if a token belongs to a specific account
    # This is a security check to ensure the authenticated user owns the resource
    # @param token [String] encrypted token
    # @param target_account_id [String] account ID to verify ownership
    # @return [Boolean] true if token belongs to target account, false otherwise
    def self.belongs_to_account?(token, target_account_id)
      payload = verify(token)
      payload[:account_id].to_s == target_account_id.to_s
    rescue StandardError
      false
    end

    # Check if a token has the required role
    # @param token [String] encrypted token
    # @param required_roles [Array<String>] roles that are authorized
    # @return [Boolean] true if token has one of the required roles
    def self.has_role?(token, required_roles)
      payload = verify(token)
      required_roles.include?(payload[:role])
    rescue StandardError
      false
    end
  end
end
