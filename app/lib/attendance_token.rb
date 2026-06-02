# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'securable'

module TickIt
  # Generates and verifies short-lived attendance tokens for QR-code-based check-in.
  # Each token encodes the event, teacher GPS position, and a tight expiry window
  # so that replayed or leaked tokens cannot be used to fake attendance.
  #
  # Payload fields:
  #   event_id    – UUID of the event being attended
  #   teacher_lat – teacher's latitude at the moment the session was started
  #   teacher_lng – teacher's longitude
  #   issued_at   – Unix timestamp when token was created
  #   expires_at  – Unix timestamp after which the token is invalid
  class AttendanceToken
    DEFAULT_EXPIRY_SECONDS = 180

    class ExpiredToken     < StandardError; end
    class InvalidToken     < StandardError; end

    def self.generate(event_id:, expires_in: DEFAULT_EXPIRY_SECONDS)
      now = Time.now.to_i
      payload = {
        event_id:   event_id,
        issued_at:  now,
        expires_at: now + expires_in
      }
      Securable.encrypt(payload.to_json)
    end

    # Decrypts and validates the token.
    # Returns the payload hash (symbol keys) on success.
    # Raises InvalidToken or ExpiredToken on failure.
    def self.verify(token)
      raise InvalidToken, 'Token is missing' if token.nil? || token.strip.empty?

      begin
        plaintext = Securable.decrypt(token)
        payload   = JSON.parse(plaintext, symbolize_names: true)
      rescue StandardError
        raise InvalidToken, 'Token could not be decrypted'
      end

      raise InvalidToken, 'Token payload is malformed' unless payload[:event_id] && payload[:expires_at]
      raise ExpiredToken, 'Attendance token has expired' if payload[:expires_at] < Time.now.to_i

      payload
    end

    # Builds the student-facing scan URL that embeds the token.
    def self.scan_url(token, base_url:)
      "#{base_url}/api/v1/attendances/scan?token=#{CGI.escape(token)}"
    end
  end
end
