# frozen_string_literal: true

require 'openssl'
require 'base64'

module TickIt
  # Encryption/decryption library for sensitive database columns
  # Uses AES-256-GCM for authenticated encryption
  class SecureDB
    ALGORITHM = 'aes-256-gcm'
    NONCE_LENGTH = 12 # GCM recommended nonce length in bytes

    # Initialize with encryption key from config
    def initialize(encryption_key = nil)
      @encryption_key = encryption_key || ENV.fetch('ENCRYPTION_KEY', nil)
      raise 'ENCRYPTION_KEY not configured' if @encryption_key.nil? || @encryption_key.strip.empty?

      # Ensure key is 32 bytes (256 bits) for AES-256
      @key = if @encryption_key.length == 32
               @encryption_key.bytes
             else
               # If not exactly 32 bytes, derive it using SHA-256
               OpenSSL::Digest::SHA256.digest(@encryption_key).bytes
             end
    end

    # Encrypt a plaintext value
    # Returns a Base64-encoded string containing: nonce + ciphertext + auth_tag
    def encrypt(plaintext)
      return nil if plaintext.nil?
      return plaintext if plaintext.is_a?(String) && plaintext.strip.empty?

      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.encrypt

      # Generate random nonce
      nonce = SecureRandom.random_bytes(NONCE_LENGTH)

      # Set key and IV (nonce for GCM mode)
      cipher.key = @key.pack('C*')
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

    # Decrypt a Base64-encoded value
    # Expects format: nonce + ciphertext + auth_tag
    def decrypt(encrypted_value)
      return nil if encrypted_value.nil?
      return encrypted_value if encrypted_value.is_a?(String) && encrypted_value.strip.empty?

      begin
        # Decode Base64
        encrypted_data = Base64.strict_decode64(encrypted_value.to_s)

        # Extract components
        nonce = encrypted_data[0...NONCE_LENGTH]
        auth_tag = encrypted_data[-16..-1] # GCM tag is 16 bytes
        ciphertext = encrypted_data[NONCE_LENGTH...-16]

        # Decrypt
        cipher = OpenSSL::Cipher.new(ALGORITHM)
        cipher.decrypt

        cipher.key = @key.pack('C*')
        cipher.iv = nonce
        cipher.auth_tag = auth_tag

        plaintext = cipher.update(ciphertext)
        plaintext += cipher.final

        plaintext
      rescue StandardError => e
        raise "Decryption failed: #{e.message}"
      end
    end

    # Class method for easier access
    def self.encrypt(plaintext, encryption_key = nil)
      new(encryption_key).encrypt(plaintext)
    end

    def self.decrypt(encrypted_value, encryption_key = nil)
      new(encryption_key).decrypt(encrypted_value)
    end
  end
end
