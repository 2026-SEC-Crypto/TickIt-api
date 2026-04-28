# frozen_string_literal: true

require 'rack/test'
require 'json'
require 'open3'
require 'tmpdir'
require_relative '../../app/controllers/app'
require_relative '../spec_helper'

RSpec.describe 'TickIt API - App Config & Root' do
  include Rack::Test::Methods

  def app
    TickIt::Api
  end

  describe 'HAPPY Path Tests' do
    describe 'DATABASE_URL configuration' do
      it 'boot fails safely when DATABASE_URL is not in environment (guard works)' do
        Dir.mktmpdir do |dir|
          secrets = File.join(dir, 'secrets.yml')
          File.write(secrets, "test:\n  # no DATABASE_URL — intentional for this spec\n")

          # Adjusted path to point to the correct project root
          project_root = File.expand_path('../..', __dir__)
          boot = File.expand_path('../support/boot_without_database_url.rb', __dir__)
          env = {
            'RACK_ENV' => 'test',
            'BUNDLE_GEMFILE' => File.join(project_root, 'Gemfile')
          }

          stdout, stderr, status = Dir.chdir(project_root) do
            Open3.capture3(env, Gem.ruby, boot, secrets)
          end

          expect(status.success?).to be(false)
          expect(stdout + stderr).to include('DATABASE_URL is missing')
        end
      end
    end

    describe 'GET /' do
      it 'returns a valid JSON welcome / status message on the root route' do
        get '/'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')

        body = JSON.parse(last_response.body)
        expect(body).to be_a(Hash)
        expect(body['message']).to be_a(String)
        expect(body['message'].strip).not_to be_empty
        expect(body['message']).to eq('TickIt API is up and running!')
      end
    end
  end

  describe 'SAD Path Tests' do
    describe 'GET /' do
      it 'does not treat root as a JSON POST endpoint' do
        post '/', '{}', { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).not_to eq(200)
      end
    end
  end
end
