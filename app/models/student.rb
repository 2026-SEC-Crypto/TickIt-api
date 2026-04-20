# frozen_string_literal: true
require 'securerandom'
require 'digest'
require_relative '../../lib/secure_db'
require_relative '../../lib/security_log'

module TickIt
  # Student enrolled in the system (check-in identity)
  class Student < Sequel::Model(TickIt::Api::DB[:students])
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    #plugin :uuid

    # Prevent direct access to encrypted columns
    set_allowed_columns :name, :email, :student_number

    one_to_many :attendance_records, class: 'TickIt::AttendanceRecord'

    def before_create
      self.id ||= SecureRandom.uuid
      super
    end

    # Encryption key from config
    def self.cipher
      @cipher ||= TickIt::SecureDB.new
    end

    # Writer methods - encrypt on assignment and store hash for lookups
    def name=(value)
      TickIt::SecurityLog.log_encryption('write', self.class.name, 'name')
      self[:secure_name] = self.class.cipher.encrypt(value)
    end

    def email=(value)
      TickIt::SecurityLog.log_encryption('write', self.class.name, 'email')
      self[:secure_email] = self.class.cipher.encrypt(value)
      self[:email_hash] = Digest::SHA256.hexdigest(value.to_s)
    end

    def student_number=(value)
      TickIt::SecurityLog.log_encryption('write', self.class.name, 'student_number')
      self[:secure_student_number] = self.class.cipher.encrypt(value)
      self[:student_number_hash] = Digest::SHA256.hexdigest(value.to_s)
    end

    # Reader methods - decrypt on access (virtual properties)
    def name
      TickIt::SecurityLog.log_encryption('read', self.class.name, 'secure_name')
      encrypted = self[:secure_name]
      encrypted ? self.class.cipher.decrypt(encrypted) : nil
    end

    def email
      TickIt::SecurityLog.log_encryption('read', self.class.name, 'secure_email')
      encrypted = self[:secure_email]
      encrypted ? self.class.cipher.decrypt(encrypted) : nil
    end

    def student_number
      TickIt::SecurityLog.log_encryption('read', self.class.name, 'secure_student_number')
      encrypted = self[:secure_student_number]
      encrypted ? self.class.cipher.decrypt(encrypted) : nil
    end

    def to_api_hash
      {
        id: id,
        name: name,
        email: email,
        student_number: student_number,
        created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601
      }
    end

    # Finder method for encrypted student_number using hash lookup (efficient)
    def self.find_by_student_number(student_number_value)
      hash = Digest::SHA256.hexdigest(student_number_value.to_s)
      first(student_number_hash: hash)
    end
  end
end

