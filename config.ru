# frozen_string_literal: true

require_relative 'app/controllers/app'
require_relative 'app/controllers/web_controllers/web'

# Mount the web application at root '/'
# Mount the API at '/api/v1'
run Rack::URLMap.new(
  '/' => TickIt::Web.freeze.app,
  '/api' => TickIt::Api.freeze.app
)
