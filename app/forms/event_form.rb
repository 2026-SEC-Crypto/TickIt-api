# frozen_string_literal: true

require 'dry-validation'

module TickIt
  EventForm = Dry::Validation.Contract do
    params do
      required(:name).filled(:string)
      required(:location).filled(:string)
      required(:start_time).filled(:string)
      required(:end_time).filled(:string)
      optional(:description).maybe(:string)
    end

    rule(:start_time, :end_time) do
      next if values[:start_time].nil? || values[:end_time].nil?

      begin
        start_t = Time.iso8601(values[:start_time])
        end_t   = Time.iso8601(values[:end_time])
        key(:end_time).failure('must be after start_time') if end_t <= start_t
      rescue ArgumentError
        nil
      end
    end
  end
end
