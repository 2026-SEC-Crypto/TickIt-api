# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('attendances') do |r|
      r.is 'scan' do
        r.post do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          body = JSON.parse(r.body.read, symbolize_names: true)
          raw_token  = body[:token].to_s
          student_lat = body[:lat].to_f
          student_lng = body[:lng].to_f

          if raw_token.empty?
            response.status = 422
            next({ error: 'Attendance token is required' }.to_json)
          end

          if student_lat.zero? && student_lng.zero?
            response.status = 422
            next({ error: 'Valid GPS coordinates (lat, lng) are required' }.to_json)
          end

          # Verify token (raises ExpiredToken or InvalidToken)
          payload = TickIt::AttendanceToken.verify(raw_token)

          event = TickIt::Event.first(id: payload[:event_id])
          if event.nil?
            response.status = 404
            next({ error: 'Event not found' }.to_json)
          end

          # Time window check
          now = Time.now
          att_start = event.attendance_start_time
          att_end   = event.attendance_end_time
          unless att_start && att_end && now >= att_start && now <= att_end
            response.status = 422
            next({ error: 'Outside the event attendance window' }.to_json)
          end

          # GPS distance check
          distance = TickIt::GpsDistance.meters(
            student_lat, student_lng,
            payload[:teacher_lat], payload[:teacher_lng]
          ).round(1)

          unless TickIt::GpsDistance.within_range?(student_lat, student_lng, payload[:teacher_lat], payload[:teacher_lng])
            response.status = 422
            next({ error: "Too far from the teacher (#{distance}m away, max #{TickIt::GpsDistance::MAX_ATTENDANCE_METERS}m)" }.to_json)
          end

          # Duplicate check
          existing = TickIt::AttendanceRecord.first(student_number: account.id.to_s, event_id: event.id.to_s)
          if existing
            response.status = 409
            next({ error: 'You have already checked in to this event' }.to_json)
          end

          # Record attendance
          record = TickIt::AttendanceRecord.create(
            student_number: account.id.to_s,
            event_id: event.id.to_s,
            check_in_time: now
          )

          response.status = 201
          {
            message: 'Attendance recorded successfully',
            event: { id: event.id, name: event.name },
            check_in_time: record.check_in_time&.iso8601
          }.to_json
        rescue TickIt::AttendanceToken::ExpiredToken => e
          response.status = 422
          { error: e.message }.to_json
        rescue TickIt::AttendanceToken::InvalidToken => e
          response.status = 422
          { error: e.message }.to_json
        rescue JSON::ParserError
          response.status = 400
          { error: 'Invalid JSON format' }.to_json
        end
      end

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
