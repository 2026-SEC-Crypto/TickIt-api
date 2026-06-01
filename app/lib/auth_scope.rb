# frozen_string_literal: true

module TickIt
  # Parses and evaluates authorization scope strings.
  # Format: "resource:action" where resource is a resource name or "*" (wildcard)
  # and action is "read" or "write".
  # Multiple scopes can be space-separated: "events:read accounts:read"
  # "write" implies read access; "read" is read-only.
  class AuthScope
    FULL_ACCESS = '*:write'.freeze
    READ_ONLY   = '*:read'.freeze

    def initialize(scope_str = FULL_ACCESS)
      @scope_str = scope_str.to_s.strip
    end

    # Returns true if this scope allows the given action on the given resource.
    # @param action [String] 'read' or 'write'
    # @param resource [String] e.g. 'events', 'accounts', 'attendances', or '*'
    def can?(action, resource)
      action   = action.to_s
      resource = resource.to_s

      parsed_scopes.any? do |s_resource, s_action|
        resource_matches = s_resource == '*' || s_resource == resource
        action_matches   = case s_action
                           when 'write' then true        # write implies read
                           when 'read'  then action == 'read'
                           else false
                           end
        resource_matches && action_matches
      end
    end

    def read_only?
      !can?('write', '*') && !parsed_scopes.any? { |_, a| a == 'write' }
    end

    def full_access?
      can?('write', '*')
    end

    def to_s
      @scope_str
    end

    private

    def parsed_scopes
      @parsed_scopes ||= @scope_str.split(/\s+/).map do |s|
        parts = s.split(':')
        r = parts[0].to_s.strip; a = parts[1].to_s.strip
        [r.empty? ? '*' : r, a.empty? ? 'read' : a]
      end
    end
  end
end
