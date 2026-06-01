# frozen_string_literal: true

require_relative 'policy'

module TickIt
  class AccountPolicy < Policy
    def can_view?
      scope_allows_read?('accounts') && (view_own? || view_any?)
    end

    def can_create?
      scope_allows_write?('accounts') && create?
    end

    def can_update?
      scope_allows_write?('accounts') && (update_own? || update_any?)
    end

    def can_delete?
      scope_allows_write?('accounts') && (delete_own? || delete_any?)
    end

    def view_own?
      return false unless authorized?

      own_account? || admin?
    end

    def view_any?
      return false unless authorized?

      admin?
    end

    def view_all?
      return false unless authorized?

      admin?
    end

    def update_own?
      return false unless authorized?

      own_account? || admin?
    end

    def update_any?
      return false unless authorized?

      admin?
    end

    def delete_own?
      return false unless authorized?

      own_account? || admin?
    end

    def delete_any?
      return false unless authorized?

      admin?
    end

    def create?
      return false unless authorized?

      admin?
    end

    def summary
      {
        view_own: view_own?,
        view_any: view_any?,
        view_all: view_all?,
        update_own: update_own?,
        update_any: update_any?,
        delete_own: delete_own?,
        delete_any: delete_any?,
        create: create?
      }
    end

    def capabilities
      {
        viewing: { own_account: view_own?, any_account: view_any?, all_accounts: view_all? },
        modifying: {
          own_account: update_own?, any_account: update_any?,
          delete_own: delete_own?, delete_any: delete_any?
        },
        creation: { create_account: create? }
      }
    end

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

    def own_account?
      return false unless account && record

      account.id == record.id
    end
  end
end
