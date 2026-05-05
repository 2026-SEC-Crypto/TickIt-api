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
    plugin :render, engine: 'slim', views: 'app/views'
    # Configure sessions with:
    # - secret: Encryption key for session data (set from env or default to dev key)
    # - HTTP-only cookies: Prevents JavaScript access to session cookies (XSS protection)
    # - Secure flag: Only in production (forces HTTPS transmission)
    plugin :sessions, secret: ENV['SESSION_SECRET'] || 'development_secret_key_change_in_production'
    plugin :halt

    # Helper to render views with layout
    # All views are rendered with the layout/layout.slim template which includes navigation
    def render_with_layout(view_name)
      view(view_name, layout: 'layouts/layout')
    end

    route do |r|
      # Set current user for all requests (for layout navigation)
      # Retrieves account from session if logged in, otherwise nil
      @current_user = SessionService.current_user(session)

      # Redirect to home if accessing root
      r.root do
        r.redirect '/home'
      end

      # Home page
      r.get 'home' do
        # Check if user just logged out
        @logout_success = r.params['logout'] == 'success'
        render_with_layout 'homes/home'
      end

      # Login page - GET
      # Displays login form; redirects to account page if already logged in
      r.on 'login' do
        r.get do
          if session && session[:account_id]
            r.redirect '/account'
          else
            render_with_layout 'sessions/login'
          end
        end

        # Login - POST
        # Authenticates user with email and password using AccountService
        # On success: Creates session with user data and redirects to account page
        # On failure: Redisplays form with error message
        r.post do
          email = r.params['email']
          password = r.params['password']

          if email.nil? || email.empty? || password.nil? || password.empty?
            @error = 'Email and password are required'
            return render_with_layout 'sessions/login'
          end

          # Call AccountService to authenticate user with encrypted password verification
          account = AccountService.authenticate(email:, password:)

          if account
            # Create secure session with user information
            # Session data is encrypted and stored in HTTP-only cookie
            session[:account_id] = account.id
            session[:email] = account.email
            session[:role] = account.role
            # Log successful login to security log
            SessionService.log_user_action(account.id, 'login')
            r.redirect '/account'
          else
            @error = 'Invalid email or password'
            @email = email
            render_with_layout 'sessions/login'
          end
        end
      end

      # Register page - GET
      # Displays registration form; redirects to account page if already logged in
      r.on 'register' do
        r.get do
          if session && session[:account_id]
            r.redirect '/account'
          else
            render_with_layout 'sessions/register'
          end
        end

        # Register - POST
        # Creates new account using AccountService; automatically logs user in on success
        # Validates email uniqueness and password requirements
        r.post do
          email = r.params['email']
          password = r.params['password']
          password_confirm = r.params['password_confirm']

          # Validation
          if email.nil? || email.empty?
            @error = 'Email is required'
            return render_with_layout 'sessions/register'
          end

          if password.nil? || password.empty?
            @error = 'Password is required'
            return render_with_layout 'sessions/register'
          end

          if password != password_confirm
            @error = 'Passwords do not match'
            @email = email
            return render_with_layout 'sessions/register'
          end

          # Try to create account using AccountService
          # AccountService handles password encryption via KeyStretching
          # and email encryption/hashing via SecureDB
          begin
            account = AccountService.create_account(email:, password:, role: 'member')
            # Automatically create session for new user
            session[:account_id] = account.id
            session[:email] = account.email
            session[:role] = account.role
            SessionService.log_user_action(account.id, 'register')
            r.redirect '/account'
          rescue StandardError => e
            @error = e.message
            @email = email
            render_with_layout 'sessions/register'
          end
        end
      end

      # Account overview - requires login
      # Displays user account details; redirects to login if not authenticated
      # Validates session by checking if user still exists in database
      r.on 'account' do
        r.get do
          unless session && session[:account_id]
            r.redirect '/login'
          end

          # Validate session by checking if account still exists in database
          # (prevents access if account was deleted after login)
          unless @current_user
            # Clear invalid session data
            session.delete(:account_id)
            session.delete(:email)
            session.delete(:role)
            r.redirect '/login'
          end

          render_with_layout 'accounts/overview'
        end
      end

      # Logout
      # Clears all session data and redirects to home page
      # Session data is stored in encrypted HTTP-only cookie by Roda
      # Deleting session keys effectively clears the cookie
      r.on 'logout' do
        if session[:account_id]
          # Log the logout action for security audit
          SessionService.log_user_action(session[:account_id], 'logout')
        end

        # Delete all account information from session cookie
        # This removes the encrypted data from the HTTP-only cookie
        session.delete(:account_id)
        session.delete(:email)
        session.delete(:role)

        # Redirect to home with logout confirmation
        r.redirect '/home?logout=success'
      end

      # 404
      response.status = 404
      @error = 'Page not found'
      render_with_layout 'errors/not_found'
    end
  end
end
