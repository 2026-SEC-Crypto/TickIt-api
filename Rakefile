# frozen_string_literal: true

require 'rspec/core/rake_task'
require './require_app'
require 'fileutils'
require 'sequel'
require 'sequel/extensions/seed'

task default: :spec

desc 'Run API specs only'
task :api_spec do
  sh 'bundle exec rspec spec/api_spec.rb'
end

desc 'Test all the specs'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/*_spec.rb'
end

desc 'Runs rubocop on tested code'
task style: %i[spec audit] do
  sh 'rubocop .'
end

desc 'Update vulnerabilities list and audit gems'
task :audit do
  sh 'bundle audit check --update'
end

desc 'Checks for release'
task release_check: %i[spec style audit] do
  puts "\nReady for release!"
end

desc 'Print environment information'
task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Run application console (pry; Hirb enabled via .pryrc)'
task console: :print_env do
  require_relative 'require_app'
  require_app('models')
  require 'pry'
  Pry.start(TickIt)
end

namespace :db do
  desc 'Load the database connection'
  task :load do
    require_app(nil)
    require 'sequel'

    Sequel.extension :migration
    @app = TickIt::Api
  end

  desc 'Load model files'
  task :load_models do
    require_app('models')
    require_app('services')
  end

  desc 'Run migrations'
  task migrate: %i[load print_env] do
    puts 'Migrating database to latest'
    Sequel::Migrator.run(@app.DB, 'app/db/migrations')
  end

  desc 'Rollback the last migration'
  task rollback: :load do
    puts "Rolling back #{@app.environment} database..."
    latest_index = Sequel::Migrator.latest_migration_index(@app.DB, 'app/db/migrations')
    Sequel::Migrator.run(@app.DB, 'app/db/migrations', target: latest_index - 1)
    puts '✓ Rollback complete'
  end

  desc 'Reset the database (drops and recreates)'
  task reset: %i[drop migrate] do
    puts '✓ Database reset complete'
  end

  desc 'Seed the database with sample data'
  task seed: %i[migrate load_models] do
    puts "Seeding #{@app.environment} database..."

    Sequel.extension :seed
    Sequel::Seed.setup(@app.environment)
    Sequel::Seeder.apply(@app.DB, 'seeds')

    puts '✓ Database seeded'
  end

  desc 'Delete all data in database; maintain tables'
  task delete: :load_models do
    puts "Deleting all data from #{@app.environment} database..."
    @app.DB[:accounts_events].delete
    @app.DB[:attendance_records].delete
    @app.DB[:events].delete
    @app.DB[:accounts].delete
    puts '✓ All data deleted'
  end

  desc 'Delete dev or test database file'
  task drop: :load do
    if @app.environment == :production
      puts 'Cannot wipe production database!'
      return
    end

    db_filename = "db/local/#{@app.environment}.db"
    FileUtils.rm_f(db_filename)
    puts "Deleted #{db_filename}"
  end

  desc 'Show database status'
  task status: :load do
    puts "Environment: #{@app.environment}"
    puts "Database URL: #{ENV.fetch('DATABASE_URL', nil)}"

    if @app.DB.tables.empty?
      puts 'Tables: None'
    else
      puts "Tables: #{@app.DB.tables.join(', ')}"
    end
  end
end
