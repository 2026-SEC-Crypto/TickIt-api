# frozen_string_literal: true

require_relative '../models/teacher_application'
require_relative '../models/account'

module TickIt
  class TeacherApplicationService
    def self.apply(account, real_name:, organization:, school_email:, notes: nil)
      raise ArgumentError, 'Real name is required' if real_name.to_s.strip.empty?
      raise ArgumentError, 'Organization is required' if organization.to_s.strip.empty?
      raise ArgumentError, 'School email is required' if school_email.to_s.strip.empty?
      raise ArgumentError, 'Invalid school email format' unless school_email.to_s.include?('@')

      existing = TeacherApplication.first(account_id: account.id, status: 'pending')
      raise ArgumentError, 'You already have a pending application' if existing

      TeacherApplication.create(
        account_id: account.id,
        real_name: real_name.to_s.strip,
        organization: organization.to_s.strip,
        school_email: school_email.to_s.strip,
        notes: notes.to_s.strip.empty? ? nil : notes.to_s.strip
      )
    end

    def self.all_applications
      TeacherApplication.order(:created_at).map do |app|
        account = Account.first(id: app.account_id)
        app.api_hash.merge(username: account&.username, email: account&.email)
      end
    end

    def self.find(id)
      TeacherApplication.first(id: id.to_s)
    end

    def self.approve(application)
      raise ArgumentError, 'Application is not pending' unless application.pending?

      application.update(status: 'approved')
      Account.first(id: application.account_id)&.update(role: 'teacher')
      application
    end

    def self.reject(application, reason: nil)
      raise ArgumentError, 'Application is not pending' unless application.pending?

      r = reason.to_s.strip
      application.update(status: 'rejected', rejection_reason: r.empty? ? nil : r)
      application
    end
  end
end
