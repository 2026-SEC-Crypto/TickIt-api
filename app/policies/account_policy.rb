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
