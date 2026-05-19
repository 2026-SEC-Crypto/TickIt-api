# frozen_string_literal: true

require_relative 'app/controllers/app'
require 'dotenv'
Dotenv.load # This loads the variables from your .env file into ENV

# Mount the web application at root '/'
# Mount the API at '/api/v1'
run Rack::URLMap.new(
  '/api' => TickIt::Api.freeze.app
)
