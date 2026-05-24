# frozen_string_literal: true

require 'dry-validation'

module TickIt
  class AuthenticateForm < Dry::Validation::Contract
    params do
      required(:email).filled(:string)
      required(:password).filled(:string)
    end
  end
end
