# frozen_string_literal: true

require_relative 'policy'

module TickIt
  # Policy for Event authorization
  # Defines what actions can be performed on event objects
  class EventPolicy < Policy
    # Check if account can view events
    def view?
      return false unless authorized?

      ['member', 'admin', 'organizer'].include?(account.role) # rubocop:disable Style/WordArray
    end

    # Check if account can create events
    def create?
      return false unless authorized?

      ['admin', 'organizer'].include?(account.role) # rubocop:disable Style/WordArray
    end

    # Check if account can update own events
    def update_own?
      return false unless authorized? || record.nil?

      admin? || (organizer? && record.account_id == account.id)
    end

    # Check if account can update any event
    def update_any?
      return false unless authorized?

      admin?
    end

    # Check if account can delete own events
    def delete_own?
      return false unless authorized? || record.nil?

      admin? || (organizer? && record.account_id == account.id)
    end

    # Check if account can delete any event
    def delete_any?
      return false unless authorized?

      admin?
    end

    # Check if account is the event organizer
    def organizer_of?
      return false unless authorized? || record.nil?

      record&.account_id == account.id
    end

    # Check if account can collaborate on events
    def collaborate?
      return false unless authorized?

      ['member', 'admin', 'organizer'].include?(account.role) # rubocop:disable Style/WordArray
    end

    # Summary of all event-related predicates and their results
    # Returns what the subject (account) can do to objects (event records)
    # @return [Hash] Predicate names mapped to their authorization results
    def summary
      {
        view: view?,
        create: create?,
        update_own: update_own?,
        update_any: update_any?,
        delete_own: delete_own?,
        delete_any: delete_any?,
        organizer_of: organizer_of?,
        collaborate: collaborate?
      }
    end

    # Capabilities grouped by action type
    # Shows what this account can do with event resources
    # @return [Hash] Grouped capabilities with descriptions
    def capabilities # rubocop:disable Metrics/MethodLength
      {
        viewing: {
          view_events: view?
        },
        creation: {
          create_event: create?
        },
        modification: {
          update_own_event: update_own?,
          update_any_event: update_any?,
          delete_own_event: delete_own?,
          delete_any_event: delete_any?
        },
        relationships: {
          organizer_of: organizer_of?,
          can_collaborate: collaborate?
        }
      }
    end
  end
end
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
