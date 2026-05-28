# frozen_string_literal: true

require_relative 'securable'

module TickIt
  # Encryption/decryption library for sensitive database columns
  # Uses AES-256-GCM for authenticated encryption via Securable module
  class SecureDB
    # Initialize with encryption key from config
    def initialize(_encryption_key = nil)
      # Securable handles key initialization internally
    end

    # Encrypt a plaintext value
    # Returns a Base64-encoded string containing: nonce + ciphertext + auth_tag
    def encrypt(plaintext, encryption_key = nil)
      Securable.encrypt(plaintext, encryption_key)
    end

    # Decrypt a Base64-encoded value
    # Expects format: nonce + ciphertext + auth_tag
    def decrypt(encrypted_value, encryption_key = nil)
      Securable.decrypt(encrypted_value, encryption_key)
    end

    # Class method for easier access
    def self.encrypt(plaintext, encryption_key = nil)
      Securable.encrypt(plaintext, encryption_key)
    end

    def self.decrypt(encrypted_value, encryption_key = nil)
      Securable.decrypt(encrypted_value, encryption_key)
    end
  end
end
