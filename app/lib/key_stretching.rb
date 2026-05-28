# frozen_string_literal: true

require 'bcrypt'

# Provides secure password hashing and verification using key-stretching.
module KeyStretching
  # Takes a plain text password and returns a salted, stretched hash string.
  def self.password_hash(password)
    # BCrypt::Password.create automatically generates a random cryptographic salt
    # and applies the hashing algorithm multiple times (stretching/work factor).
    BCrypt::Password.create(password).to_s
  end

  # Verifies if a provided plain text password matches the stored hash.
  def self.password?(password, stored_hash)
    # Reconstructs the BCrypt object from the stored hash string (which includes the salt)
    # and securely compares it against the provided plain text password.
    BCrypt::Password.new(stored_hash) == password
  end
end
