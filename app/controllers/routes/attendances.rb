# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('attendances') do |r|
      r.is String do |id|
        r.get do
          record = TickIt::AttendanceRecordService.find_record(id)
          if record
            record.api_json_hash.to_json
          else
            response.status = 404
            { error: 'Attendance record not found' }.to_json
          end
        end
      end

      r.is do
        r.get do
          { attendance_ids: TickIt::AttendanceRecordService.all_attendance_records }.to_json
        end

        r.post do
          # Only members and organizers can record attendance (403 if unauthorized)
          require_authorization!('record_attendance', 'AttendanceRecord')

          body = JSON.parse(r.body.read, symbolize_names: true)
          allowed_keys = %i[student_id event_id timestamp location]
          attempted_keys = body.keys
          illegal_keys = attempted_keys - allowed_keys

          if illegal_keys.any?
            TickIt::SecurityLog.log_mass_assignment_warning(
              'AttendanceRecord',
              attempted_keys.map(&:to_s),
              allowed_keys.map(&:to_s)
            )
            response.status = 400
            return { error: 'Illegal mass assignment detected' }.to_json
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
          response.status = 404
          { error: e.message }.to_json
        end
      end
    end
  end
end
