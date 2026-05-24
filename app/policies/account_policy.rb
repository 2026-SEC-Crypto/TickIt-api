# frozen_string_literal: true

require_relative 'policy'

module TickIt
  # Policy for Account authorization
  # Defines what actions can be performed on account objects
  class AccountPolicy < Policy
    # Check if account can view its own account details
    def view_own?
      return false unless authorized?

      account == record || admin?
    end

    # Check if account can view any account details
    def view_any?
      return false unless authorized?

      admin?
    end

    # Check if account can update its own details
    def update_own?
      return false unless authorized?

      account == record || admin?
    end

    # Check if account can update any account
    def update_any?
      return false unless authorized?

      admin?
    end

    # Check if account can delete its own account
    def delete_own?
      return false unless authorized?

      account == record || admin?
    end

    # Check if account can delete any account
    def delete_any?
      return false unless authorized?

      admin?
    end

    # Check if account can create new accounts
    def create?
      return false unless authorized?

      admin?
    end

    # Check if account can view all accounts (admin function)
    def view_all?
      return false unless authorized?

      admin?
    end

    # Summary of all account-related predicates and their results
    # Returns what the subject (account) can do to objects (account records)
    # @return [Hash] Predicate names mapped to their authorization results
    def summary
      {
        view_own: view_own?,
        view_any: view_any?,
        update_own: update_own?,
        update_any: update_any?,
        delete_own: delete_own?,
        delete_any: delete_any?,
        create: create?,
        view_all: view_all?
      }
    end

    # Capabilities grouped by action type
    # Shows what this account can do with account resources
    # @return [Hash] Grouped capabilities with descriptions
    def capabilities # rubocop:disable Metrics/MethodLength
      {
        viewing: {
          own_account: view_own?,
          any_account: view_any?,
          all_accounts: view_all?
        },
        modifying: {
          own_account: update_own?,
          any_account: update_any?,
          delete_own: delete_own?,
          delete_any: delete_any?
        },
        creation: {
          create_account: create?
        }
      }
    end
  end
end
# frozen_string_literal: true

module TickIt
  class AccountPolicy
    def initialize(account, target_account)
      @account = account
      @target_account = target_account
    end

    def can_view?
      admin? || own_account?
    end

    def can_create?
      admin?
    end

    def can_update?
      admin? || own_account?
    end

    def can_delete?
      admin? || own_account?
    end

    # Scope: admins see all accounts; others see only their own
    class Scope
      def initialize(account)
        @account = account
      end

      def viewable
        return [] unless @account
        return Account.order(:id).all if @account.admin?

        Account.where(id: @account.id).all
      end
    end

    private

    def admin?
      @account&.admin?
    end

    def own_account?
      return false unless @account && @target_account

      @account.id == @target_account.id
    end
  end
end
