# frozen_string_literal: true

require_relative '../models/teacher_application'
require_relative '../models/account'

module TickIt
  class TeacherApplicationService
    def self.apply(account)
      existing = TeacherApplication.first(account_id: account.id, status: 'pending')
      raise ArgumentError, 'You already have a pending application' if existing

      TeacherApplication.create(account_id: account.id)
    end

    def self.all_applications
      TeacherApplication.order(:created_at).map(&:api_hash)
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

    def self.reject(application)
      raise ArgumentError, 'Application is not pending' unless application.pending?

      application.update(status: 'rejected')
      application
    end
  end
end
