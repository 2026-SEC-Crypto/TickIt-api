# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('attendances') do |r|
      r.is String do |id|
        r.get do
          account = account_from_token
          record = TickIt::AttendanceRecordService.find_record(id)

          if record.nil? || !TickIt::AttendanceRecordPolicy.new(account, record, scope: scope_from_token).can_view?
            response.status = 404
            next({ error: 'Attendance record not found' }.to_json)
          end

          policy = TickIt::AttendanceRecordPolicy.new(account, record, scope: scope_from_token)
          { record: record.api_json_hash, policy: policy.summary }.to_json
        end
      end

      r.is do
        r.get do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          ids = TickIt::AttendanceRecordPolicy::Scope.new(account).viewable
          { attendance_ids: ids }.to_json
        end

        r.post do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          unless TickIt::AttendanceRecordPolicy.new(account, nil, scope: scope_from_token).can_create?
            response.status = 403
            next({ error: 'Forbidden: insufficient permissions' }.to_json)
          end

          body = JSON.parse(r.body.read, symbolize_names: true)
          allowed_keys = %i[student_id event_id timestamp location]
          illegal_keys = body.keys - allowed_keys

          if illegal_keys.any?
            TickIt::SecurityLog.log_mass_assignment_warning(
              'AttendanceRecord',
              body.keys.map(&:to_s),
              allowed_keys.map(&:to_s)
            )
            response.status = 400
            next({ error: 'Illegal mass assignment detected' }.to_json)
          end

          record = TickIt::AttendanceRecordService.create_record(
            student_id: body[:student_id],
            event_id: body[:event_id],
            timestamp: body[:timestamp]
          )

          response.status = 201
          { message: 'Attendance successfully recorded', id: record.id }.to_json
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        rescue ArgumentError => e
          response.status = 400
          { error: e.message }.to_json
        rescue StandardError => e
          response.status = 400
          { error: e.message }.to_json
        end
      end
    end
  end
end
