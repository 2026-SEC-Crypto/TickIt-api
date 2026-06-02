# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'securerandom'

module TickIt
  # Reusable encryption/decryption module for sensitive data
  # Uses AES-256-GCM for authenticated encryption
  # This module abstracts all cryptographic operations
  module Securable
    ALGORITHM = 'aes-256-gcm'
    NONCE_LENGTH = 12 # GCM recommended nonce length in bytes

    # Initializes encryption key from environment or provided parameter
    # @param encryption_key [String] encryption key (optional, defaults to ENV ENCRYPTION_KEY)
    # @return [Array<Integer>] key as array of bytes
    def self.initialize_key(encryption_key = nil)
      key = encryption_key || ENV.fetch('ENCRYPTION_KEY', nil)
      raise 'ENCRYPTION_KEY not configured' if key.nil? || key.strip.empty?

      # Ensure key is 32 bytes (256 bits) for AES-256
      if key.length == 32
        key.bytes
      else
        # If not exactly 32 bytes, derive it using SHA-256
        OpenSSL::Digest::SHA256.digest(key).bytes
      end
    end

    # Encrypt plaintext using AES-256-GCM
    # @param plaintext [String] data to encrypt
    # @param encryption_key [String] encryption key (optional)
    # @return [String] Base64-encoded encrypted data (nonce + ciphertext + auth_tag)
    def self.encrypt(plaintext, encryption_key = nil)
      return nil if plaintext.nil?
      return plaintext if plaintext.is_a?(String) && plaintext.strip.empty?

      key_bytes = initialize_key(encryption_key)

      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.encrypt

      # Generate random nonce
      nonce = SecureRandom.random_bytes(NONCE_LENGTH)

      # Set key and IV (nonce for GCM mode)
      cipher.key = key_bytes.pack('C*')
      cipher.iv = nonce

      # Encrypt the plaintext
      ciphertext = cipher.update(plaintext.to_s)
      ciphertext += cipher.final

      # Get authentication tag
      auth_tag = cipher.auth_tag

      # Combine: nonce + ciphertext + auth_tag, then Base64 encode
      encrypted_data = nonce + ciphertext + auth_tag
      Base64.strict_encode64(encrypted_data)
    end

    # Decrypt Base64-encoded encrypted data
    # @param encrypted_value [String] Base64-encoded data (nonce + ciphertext + auth_tag)
    # @param encryption_key [String] encryption key (optional)
    # @return [String] decrypted plaintext
    # @raise [RuntimeError] if decryption fails
    def self.decrypt(encrypted_value, encryption_key = nil)
      return nil if encrypted_value.nil?
      return encrypted_value if encrypted_value.is_a?(String) && encrypted_value.strip.empty?

      begin
        key_bytes = initialize_key(encryption_key)

        # Decode Base64
        encrypted_data = Base64.strict_decode64(encrypted_value.to_s)

        # Extract components
        nonce = encrypted_data[0...NONCE_LENGTH]
        auth_tag = encrypted_data[-16..-1] # GCM tag is 16 bytes
        ciphertext = encrypted_data[NONCE_LENGTH...-16]

        # Decrypt
        cipher = OpenSSL::Cipher.new(ALGORITHM)
        cipher.decrypt

        cipher.key = key_bytes.pack('C*')
        cipher.iv = nonce
        cipher.auth_tag = auth_tag

        plaintext = cipher.update(ciphertext)
        plaintext += cipher.final

        plaintext
      rescue StandardError => e
        raise "Decryption failed: #{e.message}"
      end
    end
  end
end
