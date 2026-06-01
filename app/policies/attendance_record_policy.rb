# frozen_string_literal: true

require_relative 'policy'

module TickIt
  class AttendanceRecordPolicy < Policy
    def can_view?
      view_own? || view_all?
    end

    def can_create?
      scope_allows_write?('attendances') && record_attendance?
    end

    def can_update?
      scope_allows_write?('attendances') && edit?
    end

    def can_delete?
      scope_allows_write?('attendances') && delete?
    end

    def view_own?
      return false unless authorized?

      admin? || (regular? && own_record?)
    end

    def view_all?
      return false unless authorized?

      ['admin', 'teacher'].include?(account.role)
    end

    def record_attendance?
      return false unless authorized?

      ['admin', 'teacher'].include?(account.role)
    end

    def edit?
      return false unless authorized?

      ['admin', 'teacher'].include?(account.role)
    end

    def delete?
      return false unless authorized?

      admin?
    end

    def owner?
      return false unless authorized? && !record.nil?

      record.student_number.to_s == account.id.to_s
    end

    def manage_for_event?
      return false unless authorized? && !record.nil?

      admin? || (teacher? && record.event&.account_id == account.id)
    end

    def summary
      {
        view_own: view_own?,
        view_all: view_all?,
        record: record_attendance?,
        edit: edit?,
        delete: delete?,
        owner: owner?,
        manage_for_event: manage_for_event?
      }
    end

    def capabilities
      {
        viewing: {
          view_own_attendance: view_own?,
          view_all_attendance: view_all?
        },
        modification: {
          record_attendance: record_attendance?,
          edit_attendance: edit?,
          delete_attendance: delete?
        },
        relationships: {
          is_owner: owner?,
          can_manage_for_event: manage_for_event?
        }
      }
    end

    class Scope
      def initialize(account)
        @account = account
      end

      def viewable
        return [] unless @account
        return AttendanceRecord.order(:id).select_map(:id) if @account.admin? || @account.teacher?

        AttendanceRecord.where(student_number: @account.id.to_s).select_map(:id)
      end
    end

    private

    def own_record?
      return false unless record

      record.student_number.to_s == account.id.to_s
    end
  end
end
