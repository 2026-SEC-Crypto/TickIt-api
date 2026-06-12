# frozen_string_literal: true

require 'rbnacl'
require 'base64'
require 'openssl'

module TickIt
  # Authenticated encryption using RbNaCl::SecretBox (XSalsa20-Poly1305).
  # Output format: Base64( nonce[24] + ciphertext_with_tag )
  module Securable
    def self.secret_key
      OpenSSL::Digest::SHA256.digest(ENV.fetch('ENCRYPTION_KEY'))
    end

    def self.encrypt(plaintext, _encryption_key = nil)
      return nil if plaintext.nil?
      return plaintext if plaintext.is_a?(String) && plaintext.strip.empty?

      box   = RbNaCl::SecretBox.new(secret_key)
      nonce = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.nonce_bytes)
      Base64.strict_encode64(nonce + box.box(nonce, plaintext.to_s))
    end

    def self.decrypt(encrypted_value, _encryption_key = nil)
      return nil if encrypted_value.nil?
      return encrypted_value if encrypted_value.is_a?(String) && encrypted_value.strip.empty?

      data      = Base64.strict_decode64(encrypted_value.to_s)
      nonce_len = RbNaCl::SecretBox.nonce_bytes
      RbNaCl::SecretBox.new(secret_key).open(data[0...nonce_len], data[nonce_len..])
    rescue RbNaCl::CryptoError => e
      raise "Decryption failed: #{e.message}"
    end
  end
end
