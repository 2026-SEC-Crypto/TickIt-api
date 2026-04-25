# frozen_string_literal: true

require 'rack/test'
require_relative '../../app/controllers/app'
require_relative '../spec_helper'
require_relative '../../app/models/account'

RSpec.describe 'Account Model' do
  describe 'Password Security' do
    it 'hashes the password and does not store plain text' do
      account = TickIt::Account.new
      account.password = 'super_secret_123'

      # Expect the hash to be generated
      expect(account.password_hash).not_to be_nil
      # Expect the hash to NOT equal the plain text password
      expect(account.password_hash).not_to eq 'super_secret_123'
      # Expect the plain password to be unreadable (not get!)
      expect(account.password).to be_nil
    end

    it 'correctly authenticates a valid password' do
      account = TickIt::Account.new
      account.password = 'super_secret_123'

      # Should return true for correct password
      expect(account.password?('super_secret_123')).to be true
      # Should return false for incorrect password
      expect(account.password?('wrong_password')).to be false
    end
  end

  describe 'PII Confidentiality (Email)' do
    it 'encrypts the email and creates a hash' do
      account = TickIt::Account.new
      plain_email = 'test@example.com'
      account.email = plain_email

      # Expect secure_email to be populated and encrypted
      expect(account.secure_email).not_to be_nil
      expect(account.secure_email).not_to eq plain_email

      # Expect email_hash to be populated for searching
      expect(account.email_hash).not_to be_nil
      expect(account.email_hash).not_to eq plain_email

      # Expect the getter to decrypt it back successfully
      expect(account.email).to eq plain_email
    end
  end

  describe 'Collaborator Associations (Many-to-Many)' do
    it 'allows an account to collaborate on multiple events and vice versa' do
      # 1. prepare test data: create an account and two events
      account = TickIt::Account.create(email: 'collab@example.com', password: 'password123')

      # if you have a factory or fixture system, you can use that instead to create these records more cleanly
      event1 = TickIt::Event.create(
        name: 'Music Festival',
        location: 'Taipei',
        start_time: Time.now,
        end_time: Time.now + 3600
      )
      event2 = TickIt::Event.create(
        name: 'Tech Conference',
        location: 'Hsinchu',
        start_time: Time.now,
        end_time: Time.now + 3600
      )

      # 2. make the account collaborate on both events
      account.add_collaborated_event(event1)
      account.add_collaborated_event(event2)

      # 3. test the associations (Account -> Event)：帳號能找到它的協作活動嗎？
      expect(account.collaborated_events.count).to eq 2
      expect(account.collaborated_events.map(&:name)).to include('Music Festival', 'Tech Conference')

      # 4. test the associations (Event -> Account)：活動能找到它的協作者嗎？
      expect(event1.collaborators.count).to eq 1
      expect(event1.collaborators.first.email).to eq 'collab@example.com'
    end
  end
end
