# frozen_string_literal: true

require 'dry-validation'

module TickIt
  AuthenticateForm = Dry::Validation.Contract do
    params do
      required(:email).filled(:string)
      required(:password).filled(:string)
    end
  end
end
