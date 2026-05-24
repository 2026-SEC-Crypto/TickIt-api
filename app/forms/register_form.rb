# frozen_string_literal: true

require 'dry-validation'

module TickIt
  class RegisterForm < Dry::Validation::Contract
    params do
      required(:email).filled(:string)
      required(:password).filled(:string)
      optional(:role).filled(:string)
      optional(:username).maybe(:string)
    end

    rule(:role) do
      next unless value
      key.failure('must be member, organizer, or admin') unless %w[member organizer admin].include?(value)
    end
  end
end
