# frozen_string_literal: true

# Subprocess entry: ARGV[0] = path to a Figaro YAML file without DATABASE_URL
require 'bundler/setup'

secrets_path = ARGV[0] or abort('missing secrets path')
ENV['FIGARO_SECRETS_PATH'] = secrets_path
ENV['RACK_ENV'] ||= 'test'

require_relative '../../config/environments'
