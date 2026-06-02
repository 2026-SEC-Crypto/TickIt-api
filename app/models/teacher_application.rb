# frozen_string_literal: true

require 'securerandom'

module TickIt
  class TeacherApplication < Sequel::Model(TickIt::DB[:teacher_applications])
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    set_allowed_columns :account_id, :status, :real_name, :organization, :school_email, :notes, :rejection_reason

    many_to_one :account, class: 'TickIt::Account'

    STATUSES = %w[pending approved rejected].freeze

    def before_create
      self.id ||= SecureRandom.uuid
      self.status ||= 'pending'
      super
    end

    def pending?  = status == 'pending'
    def approved? = status == 'approved'
    def rejected? = status == 'rejected'

    def api_hash
      {
        id: id,
        account_id: account_id,
        status: status,
        real_name: real_name,
        organization: organization,
        school_email: school_email,
        notes: notes,
        rejection_reason: rejection_reason,
        created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601
      }
    end
  end
end
