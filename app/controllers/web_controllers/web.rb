# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../models/account'
require_relative '../../services/account_service'
require_relative '../../services/session_service'
require_relative '../../../config/environments'
require_relative '../../../lib/security_log'

module TickIt
  class Web < Roda
    plugin :render, engine: 'slim'
    plugin :sessions
    plugin :halt

    # Configure sessions
    def self.configure_sessions
      self.opts[:sessions] = {
        cookie_options: {
          secure: ENV['RACK_ENV'] == 'production',
          http_only: true,
          path: '/'
        }
      }
    end

    route do |r|
      # Redirect to home if accessing root
      r.root do
        r.redirect '/home'
      end

      # Home page
      r.get 'home' do
        @current_user = SessionService.current_user(session)
        view 'homes/home'
      end

      # Login page - GET
      r.on 'login' do
        r.get do
          if session && session[:account_id]
            r.redirect '/account'
          else
            view 'sessions/login'
          end
        end

        # Login - POST
        r.post do
          email = r.params['email']
          password = r.params['password']

          if email.nil? || email.empty? || password.nil? || password.empty?
            @error = 'Email and password are required'
            return view 'sessions/login'
          end

          account = AccountService.authenticate(email:, password:)

          if account
            session[:account_id] = account.id
            session[:email] = account.email
            session[:role] = account.role
            SessionService.log_user_action(account.id, 'login')
            r.redirect '/account'
          else
            @error = 'Invalid email or password'
            @email = email
            view 'sessions/login'
          end
        end
      end

      # Register page - GET
      r.on 'register' do
        r.get do
          if session && session[:account_id]
            r.redirect '/account'
          else
            view 'sessions/register'
          end
        end

        # Register - POST
        r.post do
          email = r.params['email']
          password = r.params['password']
          password_confirm = r.params['password_confirm']

          # Validation
          if email.nil? || email.empty?
            @error = 'Email is required'
            return view 'sessions/register'
          end

          if password.nil? || password.empty?
            @error = 'Password is required'
            return view 'sessions/register'
          end

          if password != password_confirm
            @error = 'Passwords do not match'
            @email = email
            return view 'sessions/register'
          end

          # Try to create account
          begin
            account = AccountService.create_account(email:, password:, role: 'member')
            session[:account_id] = account.id
            session[:email] = account.email
            session[:role] = account.role
            SessionService.log_user_action(account.id, 'register')
            r.redirect '/account'
          rescue StandardError => e
            @error = e.message
            @email = email
            view 'sessions/register'
          end
        end
      end

      # Account overview - requires login
      r.on 'account' do
        r.get do
          unless session && session[:account_id]
            r.redirect '/login'
          end

          @current_user = SessionService.current_user(session)
          unless @current_user
            session.delete(:account_id)
            session.delete(:email)
            session.delete(:role)
            r.redirect '/login'
          end

          view 'accounts/overview'
        end
      end

      # Logout
      r.on 'logout' do
        if session[:account_id]
          SessionService.log_user_action(session[:account_id], 'logout')
        end

        session.delete(:account_id)
        session.delete(:email)
        session.delete(:role)
        r.redirect '/home'
      end

      # 404
      response.status = 404
      @error = 'Page not found'
      view 'errors/not_found'
    end
  end
end
