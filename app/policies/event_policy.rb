# frozen_string_literal: true

module TickIt
  class EventPolicy
    def initialize(account, event)
      @account = account
      @event = event
    end

    def can_view?
      authenticated?
    end

    def can_create?
      admin? || organizer?
    end

    def can_update?
      admin? || organizer?
    end

    def can_delete?
      admin? || organizer?
    end

    # Scope: returns the dataset of events visible to the given account
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

    private

    def authenticated?
      !@account.nil?
    end

    def admin?
      @account&.admin?
    end

    def organizer?
      @account&.organizer?
    end
  end
end
