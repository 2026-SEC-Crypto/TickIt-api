# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('account') do |r|
      r.get String do |username|
        requester = account_from_token
        if requester.nil?
          response.status = 401
          next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
        end

        scope = scope_from_token
        unless scope.can?('read', 'accounts')
          response.status = 403
          next({ error: 'Forbidden: insufficient scope' }.to_json)
        end

        target = TickIt::Account.first(username: username)
        if target.nil? || !TickIt::AccountPolicy.new(requester, target, scope: scope).can_view?
          response.status = 404
          next({ error: 'Account not found' }.to_json)
        end

        {
          account: {
            id: target.id,
            username: target.username,
            email: target.email,
            role: target.role
          }
        }.to_json
      end
    end
  end
end
