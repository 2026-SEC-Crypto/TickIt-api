# frozen_string_literal: true

module TickIt
  # Base policy class for authorization checks
  # Provides framework for permission evaluation and summarization
  class Policy
    attr_reader :account, :record

    # Initialize with an account (subject) and optional record (object)
    # @param account [Account] The account performing the action
    # @param record [Object] Optional record being acted upon
    def initialize(account, record = nil)
      @account = account
      @record = record
    end

    # Check if account is authorized
    # @return [Boolean]
    def authorized?
      !account.nil?
    end

    # Check if account is admin
    # @return [Boolean]
    def admin?
      account&.admin?
    end

    def teacher?
      account&.teacher?
    end

    def regular?
      account&.regular?
    end

    # Get numeric role priority (higher = more privileged)
    # @return [Integer]
    def role_priority
      return 0 unless account

      case account.role
      when 'admin' then 3
      when 'teacher' then 2
      when 'regular' then 1
      else 0
      end
    end

    # Summary method that returns all predicates and their results
    # Subclasses should override this to provide specific predicates
    # @return [Hash] Hash of predicate names to boolean results
    def summary
      {}.freeze
    end

    # Export capabilities as a human-readable hash
    # @return [Hash] Hash of action groupings and their allowed predicates
    def capabilities
      {}.freeze
    end
  end
end
