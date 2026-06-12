# frozen_string_literal: true

require 'rbnacl'
require 'base64'

# Password hashing using RbNaCl::PasswordHash::SCrypt (libsodium).
# Legacy BCrypt hashes are still verified so existing passwords keep working.
module KeyStretching
  SCRYPT_OPSLIMIT = 524_288   # ~interactive workload
  SCRYPT_MEMLIMIT = 16_777_216 # 16 MB
  SCRYPT_HASH_LEN = 64

  def self.password_hash(password)
    salt = RbNaCl::Random.random_bytes(RbNaCl::PasswordHash::SCrypt::SALTBYTES)
    hash = RbNaCl::PasswordHash.scrypt(password, salt, SCRYPT_OPSLIMIT, SCRYPT_MEMLIMIT, SCRYPT_HASH_LEN)
    "scrypt$#{Base64.strict_encode64(salt)}$#{Base64.strict_encode64(hash)}"
  end

  def self.password?(password, stored_hash)
    if stored_hash.to_s.start_with?('$2') # legacy BCrypt
      require 'bcrypt'
      return BCrypt::Password.new(stored_hash) == password
    end

    parts = stored_hash.to_s.split('$')
    return false unless parts.length == 3 && parts[0] == 'scrypt'

    salt     = Base64.strict_decode64(parts[1])
    expected = Base64.strict_decode64(parts[2])
    actual   = RbNaCl::PasswordHash.scrypt(password, salt, SCRYPT_OPSLIMIT, SCRYPT_MEMLIMIT, SCRYPT_HASH_LEN)
    RbNaCl::Util.verify64(expected, actual)
  rescue StandardError
    false
  end
end
