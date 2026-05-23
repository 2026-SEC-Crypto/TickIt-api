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
