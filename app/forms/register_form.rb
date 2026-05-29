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
      key.failure('must be regular, teacher, or admin') unless %w[regular teacher admin].include?(value)
    end
  end
end
