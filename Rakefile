# frozen_string_literal: true

require 'rspec/core/rake_task'
require './require_app'
require 'fileutils'

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

task :print_env do # rubocop:disable Rake/Desc
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Run application console (pry)'
task console: :print_env do
  sh 'pry -r ./config/environments'
end

namespace :db do
  task :load do # rubocop:disable Rake/Desc
    require_app(nil)
    require 'sequel'

    Sequel.extension :migration
    @app = TickIt::Api
  end

  task :load_models do # rubocop:disable Rake/Desc
    require_app('models')
  end

  desc 'Run migrations'
  task migrate: %i[load print_env] do
    puts 'Migrating database to latest'
    Sequel::Migrator.run(@app.DB, 'app/db/migrations')
  end

  desc 'Rollback the last migration'
  task rollback: :load do
    puts "Rolling back #{@app.environment} database..."
    Sequel::Migrator.run(@app.DB, 'app/db/migrations', target: Sequel::Migrator.latest_migration_index(@app.DB, 'app/db/migrations') - 1)
    puts "✓ Rollback complete"
  end

  desc 'Reset the database (drops and recreates)'
  task reset: [:drop, :migrate] do
    puts "✓ Database reset complete"
  end

  desc 'Seed the database with sample data'
  task seed: [:migrate, :load_models] do
    puts "Seeding #{@app.environment} database..."

    # Create sample data
    students = @app.DB[:students]
    events = @app.DB[:events]
    attendance_records = @app.DB[:attendance_records]

    # Sample students
    students.insert(name: 'Alice Johnson', email: 'alice@example.com', student_number: 'STU001')
    students.insert(name: 'Bob Smith', email: 'bob@example.com', student_number: 'STU002')
    students.insert(name: 'Carol White', email: 'carol@example.com', student_number: 'STU003')

    # Sample events
    events.insert(name: 'Web Development Workshop', location: 'Room 101', start_time: Time.now, end_time: Time.now + 3600, description: 'Introduction to Web Dev')
    events.insert(name: 'Security Seminar', location: 'Room 202', start_time: Time.now, end_time: Time.now + 5400, description: 'Application Security Basics')

    # Sample attendance records
    attendance_records.insert(student_id: 1, event_id: 1, status: 'present', check_in_time: Time.now)
    attendance_records.insert(student_id: 2, event_id: 1, status: 'present', check_in_time: Time.now)
    attendance_records.insert(student_id: 1, event_id: 2, status: 'absent')

    puts "✓ Database seeded"
  end

  desc 'Delete all data in database; maintain tables'
  task delete: :load_models do
    puts "Deleting all data from #{@app.environment} database..."
    @app.DB[:attendance_records].delete
    @app.DB[:events].delete
    @app.DB[:students].delete
    puts "✓ All data deleted"
  end

  desc 'Delete dev or test database file'
  task drop: :load do
    if @app.environment == :production
      puts 'Cannot wipe production database!'
      return
    end

    db_filename = "db/local/#{@app.environment}.db"
    FileUtils.rm(db_filename) if File.exist?(db_filename)
    puts "Deleted #{db_filename}"
  end

  desc 'Show database status'
  task status: :load do
    puts "Environment: #{@app.environment}"
    puts "Database URL: #{ENV['DATABASE_URL']}"

    if @app.DB.tables.empty?
      puts "Tables: None"
    else
      puts "Tables: #{@app.DB.tables.join(', ')}"
    end
  end
end
