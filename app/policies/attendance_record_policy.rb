# frozen_string_literal: true

require_relative 'policy'

module TickIt
  # Policy for AttendanceRecord authorization
  # Defines what actions can be performed on attendance record objects
  class AttendanceRecordPolicy < Policy
    # Check if account can view own attendance records
    def view_own?
      return false unless authorized? || record.nil?

      admin? || (member? && record.account_id == account.id)
    end

    # Check if account can view any/all attendance records
    def view_all?
      return false unless authorized?

      ['admin', 'organizer'].include?(account.role) # rubocop:disable Style/WordArray
    end

    # Check if account can record attendance
    def record?
      return false unless authorized?

      ['admin', 'organizer'].include?(account.role) # rubocop:disable Style/WordArray
    end

    # Check if account can edit attendance records
    def edit?
      return false unless authorized?

      ['admin', 'organizer'].include?(account.role) # rubocop:disable Style/WordArray
    end

    # Check if account can delete attendance records
    def delete?
      return false unless authorized?

      admin?
    end

    # Check if account owns the attendance record
    def owner?
      return false unless authorized? || record.nil?

      record&.account_id == account.id
    end

    # Check if account can manage attendance for specific event
    def manage_for_event?
      return false unless authorized? || record.nil? || record.event.nil?

      admin? || (organizer? && record.event.account_id == account.id)
    end

    # Summary of all attendance-related predicates and their results
    # Returns what the subject (account) can do to objects (attendance records)
    # @return [Hash] Predicate names mapped to their authorization results
    def summary
      {
        view_own: view_own?,
        view_all: view_all?,
        record: record?,
        edit: edit?,
        delete: delete?,
        owner: owner?,
        manage_for_event: manage_for_event?
      }
    end

    # Capabilities grouped by action type
    # Shows what this account can do with attendance record resources
    # @return [Hash] Grouped capabilities with descriptions
    def capabilities # rubocop:disable Metrics/MethodLength
      {
        viewing: {
          view_own_attendance: view_own?,
          view_all_attendance: view_all?
        },
        modification: {
          record_attendance: record?,
          edit_attendance: edit?,
          delete_attendance: delete?
        },
        relationships: {
          is_owner: owner?,
          can_manage_for_event: manage_for_event?
        }
      }
    end
  end
end
# frozen_string_literal: true

module TickIt
  class AttendanceRecordPolicy
    def initialize(account, record)
      @account = account
      @record = record
    end

    def can_view?
      admin? || organizer? || own_record?
    end

    def can_create?
      admin? || organizer?
    end

    def can_update?
      admin? || organizer?
    end

    def can_delete?
      admin?
    end

    # Scope: admins/organizers see all records; members see only their own
    class Scope
      def initialize(account)
        @account = account
      end

      def viewable
        return [] unless @account
        return AttendanceRecord.order(:id).select_map(:id) if @account.admin? || @account.organizer?

        AttendanceRecord.where(student_number: @account.id.to_s).select_map(:id)
      end
    end

    private

    def admin?
      @account&.admin?
    end

    def organizer?
      @account&.organizer?
    end

    def own_record?
      return false unless @account && @record

      @record.student_number.to_s == @account.id.to_s
    end
  end
end
