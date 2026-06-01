# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('auth') do |r|
      # POST /api/v1/auth/authenticate
      r.on 'authenticate' do
        r.post do
          body = JSON.parse(r.body.read)
          form = TickIt::AuthenticateForm.new.call(body)

          unless form.success?
            response.status = 400
            next({ errors: form.errors.to_h }.to_json)
          end

          account_data = TickIt::AccountService.authenticate(
            email: form.values[:email],
            password: form.values[:password]
          )

          if account_data
            session.update(TickIt::SessionService.create_session(account_data))
            response.status = 200
            {
              account: {
                id: account_data[:id],
                username: account_data[:username],
                email: account_data[:email],
                role: account_data[:role],
                auth_token: account_data[:auth_token]
              }
            }.to_json
          else
            response.status = 401
            { error: 'Invalid credentials' }.to_json
          end
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        end
      end

      # POST /api/v1/auth/register
      r.on 'register' do
        r.post do
          body = JSON.parse(r.body.read)
          form = TickIt::RegisterForm.new.call(body)

          unless form.success?
            response.status = 400
            next({ errors: form.errors.to_h }.to_json)
          end

          account_data = TickIt::AccountService.create_account(
            email: form.values[:email],
            password: form.values[:password],
            role: form.values[:role] || 'regular',
            username: form.values[:username]
          )

          response.status = 201
          {
            message: 'Account created successfully',
            account: {
              id: account_data[:id],
              username: account_data[:username],
              email: account_data[:email],
              role: account_data[:role],
              auth_token: account_data[:auth_token]
            }
          }.to_json
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        rescue StandardError => e
          status = e.message.include?('already exists') ? 409 : 400
          response.status = status
          { error: e.message }.to_json
        end
      end

      # POST /api/v1/auth/sso
      r.on 'sso' do
        r.post do
          body = JSON.parse(r.body.read)
          form = TickIt::SsoForm.new.call(body)

          unless form.success?
            response.status = 400
            next({ errors: form.errors.to_h }.to_json)
          end

          provider = form.values[:provider].to_s
          id_token = form.values[:id_token].to_s

          payload = TickIt::SsoService.verify(provider: provider, id_token: id_token)
          email = payload['email'].to_s
          username = payload['name'].to_s.strip
          username = email.split('@').first if username.empty?

          account_data = TickIt::AccountService.find_or_create_sso_account(
            provider: provider,
            sub: payload['sub'].to_s,
            email: email,
            username: username,
            avatar_url: payload['picture']
          )

          session.update(TickIt::SessionService.create_session(account_data))
          response.status = 200
          {
            account: {
              id: account_data[:id],
              username: account_data[:username],
              email: account_data[:email],
              role: account_data[:role],
              avatar_url: account_data[:avatar_url],
              auth_token: account_data[:auth_token]
            }
          }.to_json
        rescue TickIt::SsoService::InvalidToken => e
          response.status = 401
          { error: e.message }.to_json
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        end
      end

      r.on 'api_key' do
        r.post do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          api_key = TickIt::AccountService.generate_api_key(account)
          { api_key: api_key, scope: TickIt::AuthScope::READ_ONLY,
            note: 'This key provides read-only access. Use as: Authorization: Bearer <key>' }.to_json
        end
      end
    end
  end
end
