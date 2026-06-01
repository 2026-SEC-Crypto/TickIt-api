# frozen_string_literal: true

require_relative 'policy'

module TickIt
  class EventPolicy < Policy
    def can_view?
      view?
    end

    def can_create?
      scope_allows_write?('events') && create?
    end

    def can_update?
      scope_allows_write?('events') && (update_own? || update_any?)
    end

    def can_delete?
      scope_allows_write?('events') && (delete_own? || delete_any?)
    end

    def view?
      return false unless authorized?

      ['regular', 'admin', 'teacher'].include?(account.role)
    end

    def create?
      return false unless authorized?

      ['admin', 'teacher'].include?(account.role)
    end

    def update_own?
      return false unless authorized? && !record.nil?

      admin? || (teacher? && collaborator_of?)
    end

    def update_any?
      return false unless authorized?

      admin?
    end

    def delete_own?
      return false unless authorized? && !record.nil?

      admin? || (teacher? && collaborator_of?)
    end

    def delete_any?
      return false unless authorized?

      admin?
    end

    def teacher_of?
      collaborator_of?
    end

    def collaborate?
      return false unless authorized?

      ['regular', 'admin', 'teacher'].include?(account.role)
    end

    def summary
      {
        view: view?,
        create: create?,
        update_own: update_own?,
        update_any: update_any?,
        delete_own: delete_own?,
        delete_any: delete_any?,
        teacher_of: teacher_of?,
        collaborate: collaborate?
      }
    end

    def capabilities
      {
        viewing: { view_events: view? },
        creation: { create_event: create? },
        modification: {
          update_own_event: update_own?,
          update_any_event: update_any?,
          delete_own_event: delete_own?,
          delete_any_event: delete_any?
        },
        relationships: {
          teacher_of: teacher_of?,
          can_collaborate: collaborate?
        }
      }
    end

    def collaborator_of?
      return false unless authorized? && !record.nil?

      record.collaborators.any? { |c| c.id.to_s == account.id.to_s }
    end

    class Scope
      def initialize(account)
        @account = account
      end

      def viewable
        return [] unless @account

        attended_ids = TickIt::DB[:attendance_records]
          .where(student_number: @account.id.to_s)
          .select(:event_id)

        if @account.teacher? || @account.admin?
          created_ids = TickIt::DB[:accounts_events]
            .where(account_id: @account.id.to_s)
            .select(:event_id)

          Event.where(id: created_ids).or(id: attended_ids).order(:id)
        else
          Event.where(id: attended_ids).order(:id)
        end
      end
    end
  end
end
