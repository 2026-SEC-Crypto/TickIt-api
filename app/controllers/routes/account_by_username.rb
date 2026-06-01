# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('account_by_username') do |r|
      r.get String do |username|
        result = TickIt::AccountService.find_account_by_username(username, token: raw_token)
        { account: result }.to_json
      rescue TickIt::TokenVerifiable::Unauthorized => e
        response.status = 401
        { error: e.message }.to_json
      rescue TickIt::TokenVerifiable::Forbidden
        response.status = 404
        { error: 'Account not found' }.to_json
      end
    end
  end
end
