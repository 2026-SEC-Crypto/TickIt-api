# frozen_string_literal: true

require_relative 'auth_token'
require_relative 'auth_scope'

module TickIt
  # Mixin for service objects that need to extract auth_scope from a Bearer token
  # and pass it to policy objects for authorization checks.
  module TokenVerifiable
    class Unauthorized < StandardError; end
    class Forbidden    < StandardError; end

    # Verify the token and return [account, scope].
    # Raises Unauthorized if the token is missing or invalid.
    def extract_auth(token)
      raise Unauthorized, 'Valid Bearer token required' if token.nil? || token.strip.empty?

      payload = AuthToken.verify(token)
      raise Unauthorized, 'Invalid or expired token' unless payload

      account = Account.first(id: payload[:account_id].to_s)
      raise Unauthorized, 'Account not found' unless account

      scope = AuthScope.new(payload.dig(:scope) || AuthScope::FULL_ACCESS)
      [account, scope]
    end
  end
end
