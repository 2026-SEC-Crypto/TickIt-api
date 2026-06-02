# frozen_string_literal: true

require_relative 'app/controllers/app'
require 'dotenv'
require 'rack/cors'

Dotenv.load

web_origin = ENV.fetch('WEB_APP_URL', 'http://localhost:9292')

use Rack::Cors do
  allow do
    origins web_origin, 'http://localhost:9292', 'http://localhost:3000'
    resource '/api/*',
             headers: :any,
             methods: %i[get post patch put delete options],
             credentials: false
  end
end

run Rack::URLMap.new(
  '/api' => TickIt::Api.freeze.app
)
