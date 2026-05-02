# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('students') do |r|
      r.is String, 'events' do |student_id|
        r.get do
          records = TickIt::AttendanceRecordService.records_for_student(student_id)
          event_ids = records.map { |record| record[:event_id] }.uniq
          events = event_ids.filter_map do |event_id|
            event = TickIt::EventService.find_event(event_id)
            event&.to_api_hash
          end

          { student_id: student_id, events: events }.to_json
        end
      end

      r.is String, 'courses' do |student_id|
        r.get do
          records = TickIt::AttendanceRecordService.records_for_student(student_id)
          event_ids = records.map { |record| record[:event_id] }.uniq
          courses = event_ids.filter_map do |event_id|
            event = TickIt::EventService.find_event(event_id)
            event&.to_api_hash
          end

          { student_id: student_id, courses: courses }.to_json
        end
      end
    end
  end
end
