# frozen_string_literal: true

require 'dry-validation'

module TickIt
  class SsoForm < Dry::Validation::Contract
    params do
      required(:provider).filled(:string)
      required(:id_token).filled(:string)
    end
  end
end
