# frozen_string_literal: true

require_relative 'policy'

module TickIt
  class TeacherApplicationPolicy < Policy
    def can_create?
      scope_allows_write?('applications') && apply?
    end

    def can_view?
      scope_allows_read?('applications') && (view_own? || view_all?)
    end

    def can_list_all?
      scope_allows_read?('applications') && admin?
    end

    def can_approve?
      scope_allows_write?('applications') && admin?
    end

    def can_reject?
      scope_allows_write?('applications') && admin?
    end

    def summary
      {
        apply: apply?,
        view_own: view_own?,
        view_all: view_all?,
        approve: admin?,
        reject: admin?
      }
    end

    private

    def apply?
      authorized? && regular?
    end

    def view_own?
      return false unless authorized? && record

      account.id == record.account_id
    end

    def view_all?
      admin?
    end
  end
end
