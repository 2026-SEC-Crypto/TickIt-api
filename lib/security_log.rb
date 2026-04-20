# frozen_string_literal: true

require 'logger'

module TickIt
  # Security event logging
  class SecurityLog
    @@logger = Logger.new($stderr)
    @@logger.level = Logger::DEBUG

    def self.setup_logger(log_file = nil)
      if log_file
        @@logger = Logger.new(log_file)
      else
        @@logger = Logger.new($stderr)
      end
      @@logger.level = Logger::DEBUG
      @@logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} - #{msg}\n"
      end
    end

    # Log mass assignment attempts - show keys but NOT values
    def self.log_mass_assignment_warning(model_class, attempted_keys, allowed_keys)
      attempted_str = attempted_keys.join(', ')
      allowed_str = allowed_keys.join(', ')
      msg = "MASS ASSIGNMENT ATTEMPT - Model: #{model_class}, " \
            "Attempted keys: [#{attempted_str}], " \
            "Allowed keys: [#{allowed_str}]"
      @@logger.warn(msg)
    end

    # Log unknown/unhandled errors (typically 500 errors)
    def self.log_error(error, context = {})
      backtrace = error.backtrace&.first(5)&.join("\n  ") || 'No backtrace'
      context_str = context.map { |k, v| "#{k}: #{v}" }.join(', ')
      msg = "ERROR: #{error.class} - #{error.message}\n" \
            "Context: #{context_str}\n" \
            "Backtrace:\n  #{backtrace}"
      @@logger.error(msg)
    end

    # Log encryption operations (info level)
    def self.log_encryption(action, model_class, column)
      @@logger.info("ENCRYPTION - Action: #{action}, Model: #{model_class}, Column: #{column}")
    end

    # General security event
    def self.log_security_event(event_type, message, severity = :info)
      level_method = {
        debug: :debug,
        info: :info,
        warn: :warn,
        error: :error
      }.fetch(severity, :info)

      @@logger.send(level_method, "SECURITY EVENT - Type: #{event_type}, Message: #{message}")
    end
  end
end
