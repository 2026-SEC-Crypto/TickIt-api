require 'rbnacl'
require 'base64'
require 'json'

module TickIt
  class SignedRequest # rubocop:disable Style/Documentation
    class InvalidSignature < StandardError; end

    def self.verify(body)
      verify_key = RbNaCl::Signatures::Ed25519::VerifyKey.new(
        Base64.strict_decode64(ENV.fetch('VERIFY_KEY'))
      )

      data = body.fetch('data')
      signature = Base64.strict_decode64(body.fetch('signature'))

      verify_key.verify(signature, JSON.generate(data))

      data
    rescue KeyError, RbNaCl::BadSignatureError
      raise InvalidSignature
    end
  end
end
