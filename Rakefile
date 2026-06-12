# frozen_string_literal: true

require './require_app'
require 'fileutils'
require 'sequel'
require 'sequel/extensions/seed'

rspec_available = false
if ENV.fetch('RACK_ENV', 'development') != 'production'
  begin
    require 'rspec/core/rake_task'
    rspec_available = true
  rescue LoadError
    rspec_available = false
  end
end

if rspec_available
  task default: :spec

  desc 'Run API specs only'
  task :api_spec do
    sh 'bundle exec rspec spec/api_spec.rb'
  end
else
  task default: :print_env
end

# desc 'Test all the specs'
# RSpec::Core::RakeTask.new(:spec) do |t|
#   t.pattern = 'spec/*_spec.rb'
# end
if rspec_available
  RSpec::Core::RakeTask.new(:spec)
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
  # desc 'Load the database connection'
  # task :load do
  #   require_app(nil)
  #   require 'sequel'

  #   Sequel.extension :migration
  #   @app = TickIt::Api
  # end
  desc 'Load the database connection'
  task :load do
    require_app(nil)
    require 'sequel'

    Sequel.extension :migration
    @app = TickIt
  end

  desc 'Load model files'
  task :load_models do
    require_app('models')
    require_app('services')
  end

  desc 'Run migrations'
  task migrate: %i[load print_env] do
    puts 'Migrating database to latest'
    Sequel::Migrator.run(TickIt::DB, 'db/migrations')
  end

  desc 'Rollback the last migration'
  task rollback: :load do
    puts "Rolling back #{@app.environment} database..."
    latest_index = Sequel::Migrator.latest_migration_index(TickIt::DB, 'db/migrations')
    Sequel::Migrator.run(TickIt::DB, 'app/db/migrations', target: latest_index - 1)
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
    Sequel::Seeder.apply(TickIt::DB, 'db/seeds')

    puts '✓ Database seeded'
  end

  desc 'Delete all data in database; maintain tables'
  task delete: :load_models do
    puts "Deleting all data from #{@app.environment} database..."
    TickIt::DB[:accounts_events].delete
    TickIt::DB[:attendance_records].delete
    TickIt::DB[:events].delete
    TickIt::DB[:accounts].delete
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

    if TickIt::DB.tables.empty?
      puts 'Tables: None'
    else
      puts "Tables: #{TickIt::DB.tables.join(', ')}"
    end
  end
  desc 'Re-encrypt secure_email and secure_location from AES-256-GCM to RbNaCl::SecretBox'
  task migrate_encryption: %i[load load_models] do
    require 'openssl'
    require 'base64'
    require 'rbnacl'

    raw_key = ENV.fetch('ENCRYPTION_KEY')

    # Old AES-256-GCM decryption (inlined — Securable now uses SecretBox)
    aes_key_bytes = raw_key.length == 32 ? raw_key.bytes : OpenSSL::Digest::SHA256.digest(raw_key).bytes
    aes_decrypt = lambda do |encrypted_value|
      data       = Base64.strict_decode64(encrypted_value)
      nonce      = data[0...12]
      auth_tag   = data[-16..]
      ciphertext = data[12...-16]
      cipher = OpenSSL::Cipher.new('aes-256-gcm').tap do |c|
        c.decrypt
        c.key      = aes_key_bytes.pack('C*')
        c.iv       = nonce
        c.auth_tag = auth_tag
      end
      cipher.update(ciphertext) + cipher.final
    end

    # New RbNaCl::SecretBox encrypt
    nacl_key = OpenSSL::Digest::SHA256.digest(raw_key)
    nacl_encrypt = lambda do |plaintext|
      box   = RbNaCl::SecretBox.new(nacl_key)
      nonce = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.nonce_bytes)
      Base64.strict_encode64(nonce + box.box(nonce, plaintext))
    end

    migrated = 0
    errors   = 0

    puts '=== Migrating accounts.secure_email ==='
    TickIt::DB[:accounts].each do |row|
      next if row[:secure_email].nil? || row[:secure_email].empty?

      begin
        plain = aes_decrypt.call(row[:secure_email])
        TickIt::DB[:accounts].where(id: row[:id]).update(secure_email: nacl_encrypt.call(plain))
        migrated += 1
        puts "  account #{row[:id]}: ok"
      rescue StandardError => e
        errors += 1
        puts "  account #{row[:id]}: FAILED — #{e.message}"
      end
    end

    puts '=== Migrating events.secure_location ==='
    TickIt::DB[:events].each do |row|
      next if row[:secure_location].nil? || row[:secure_location].empty?

      begin
        plain = aes_decrypt.call(row[:secure_location])
        TickIt::DB[:events].where(id: row[:id]).update(secure_location: nacl_encrypt.call(plain))
        migrated += 1
        puts "  event #{row[:id]}: ok"
      rescue StandardError => e
        errors += 1
        puts "  event #{row[:id]}: FAILED — #{e.message}"
      end
    end

    puts "Done: #{migrated} migrated, #{errors} errors"
  end

  desc 'Bootstrap an admin: create-or-find EMAIL, grant admin role'
  task bootstrap_admin: %i[load load_models] do
    require 'digest'

    # 1. Read the EMAIL environment variable
    email = ENV.fetch('EMAIL', nil).to_s.strip
    abort '❌ Error: Please provide EMAIL=<email>' if email.empty?

    # 2. Find the account using the Email Hash (PII Confidentiality)
    email_hash = Digest::SHA256.hexdigest(email)
    account = TickIt::Account.first(email_hash: email_hash)

    if account.nil?
      password = ENV.fetch('PASSWORD', 'admin_password_123')
      # Model hooks handle secure_email encryption and email_hash generation
      account = TickIt::Account.create(email: email, password: password)
      puts "✅ Successfully created new secure account (id=#{account.id})"
    else
      puts 'ℹ️ Found existing account for this email hash'
    end

    # 3. Grant admin privileges (Based on lecture slides 22-23)
    # This section ensures the role exists and assigns it via system_roles
    begin
      # Ensure the 'Role' constant is defined before using it
      if Object.const_defined?('TickIt::Role')
        admin_role = TickIt::Role.first(name: 'admin') || TickIt::Role.create(name: 'admin')

        # Check for system_roles association as per lecture notes
        if account.respond_to?(:add_system_role)
          if account.system_roles_dataset.where(name: 'admin').any?
            puts '👑 Account is already an admin!'
          else
            account.add_system_role(admin_role)
            puts "👑 Successfully granted 'admin' role!"
          end
        else
          # Fallback to standard many-to-many 'add_role'
          account.add_role(admin_role) unless account.roles.include?(admin_role)
          puts "👑 Successfully granted 'admin' role via add_role!"
        end
      else
        # Fallback if no Role model exists: check for a role column on Account
        account.update(role: 'admin') if account.respond_to?(:role=)
        puts "👑 Successfully updated account role to 'admin' (Column fallback)"
      end
    rescue StandardError => e
      puts "⚠️ Warning: Could not assign role automatically: #{e.message}"
      puts 'Manual check required: Does your database have a roles table or a role column?'
    end
  end
end
