# frozen_string_literal: true

require 'http'
require 'json'
require 'jwt'

module TickIt
  class SsoService
    class InvalidToken < StandardError; end

    PROVIDERS = {
      'google' => {
        jwks_uri: ENV.fetch('GOOGLE_JWKS_URI', 'https://www.googleapis.com/oauth2/v3/certs'),
        client_id: ENV.fetch('GOOGLE_CLIENT_ID', nil),
        issuer: ['https://accounts.google.com', 'accounts.google.com']
      }
    }.freeze

    def self.verify(provider:, id_token:)
      config = PROVIDERS[provider.to_s]
      raise InvalidToken, 'Unsupported SSO provider' unless config
      raise InvalidToken, 'Missing provider client ID' if config[:client_id].to_s.strip.empty?

      jwks = fetch_jwks(config[:jwks_uri])
      payload, = JWT.decode(
        id_token,
        nil,
        true,
        algorithms: ['RS256'],
        jwks: jwks,
        aud: config[:client_id],
        verify_aud: true,
        iss: config[:issuer],
        verify_iss: true
      )

      validate_payload!(payload)
      payload
    rescue JWT::DecodeError => e
      raise InvalidToken, e.message
    end

    def self.fetch_jwks(uri)
      response = HTTP.get(uri)
      raise InvalidToken, 'JWKS fetch failed' unless response.status.success?

      JSON.parse(response.body.to_s)
    rescue JSON::ParserError => e
      raise InvalidToken, "JWKS parse failed: #{e.message}"
    end

    def self.validate_payload!(payload)
      email = payload['email'].to_s.strip
      sub = payload['sub'].to_s.strip
      email_verified = payload['email_verified']

      raise InvalidToken, 'Missing email in id_token' if email.empty?
      raise InvalidToken, 'Missing sub in id_token' if sub.empty?
      return unless email_verified == false

      raise InvalidToken, 'Email not verified by provider'
    end
  end
end
