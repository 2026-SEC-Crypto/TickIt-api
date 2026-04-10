# frozen_string_literal: true

require 'rspec'
require 'rack/test'
require 'json'

RSpec.configure do |config|
  config.formatter = :documentation
  config.color = true
end
