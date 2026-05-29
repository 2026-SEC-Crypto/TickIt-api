# frozen_string_literal: true

require_relative 'policy'

module TickIt
  class EventPolicy < Policy
    def can_view?
      view?
    end

    def can_create?
      create?
    end

    def can_update?
      update_own? || update_any?
    end

    def can_delete?
      delete_own? || delete_any?
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

      admin? || (teacher? && record.account_id == account.id)
    end

    def update_any?
      return false unless authorized?

      admin?
    end

    def delete_own?
      return false unless authorized? && !record.nil?

      admin? || (teacher? && record.account_id == account.id)
    end

    def delete_any?
      return false unless authorized?

      admin?
    end

    def teacher_of?
      return false unless authorized? && !record.nil?

      record&.account_id == account.id
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

    class Scope
      def initialize(account)
        @account = account
      end

      def viewable
        return [] unless @account

        Event
          .join(:accounts_events, event_id: :id)
          .where(Sequel[:accounts_events][:account_id] => @account.id.to_s)
          .order(Sequel[:events][:id])
      end
    end
  end
end
