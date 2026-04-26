# frozen_string_literal: true

Sequel.seed(:development, :test) do
  def run
    TickIt::Api::DB.transaction do
      TickIt::Api::DB[:accounts_events].delete
      TickIt::Api::DB[:attendance_records].delete
      TickIt::Api::DB[:events].delete
      TickIt::Api::DB[:accounts].delete

      accounts = [
        { email: 'alice@example.com', password: 'alice_password_123', role: 'organizer' },
        { email: 'bob@example.com', password: 'bob_password_123', role: 'member' },
        { email: 'carol@example.com', password: 'carol_password_123', role: 'admin' }
      ]

      accounts.each do |account_data|
        TickIt::AccountService.create_account(**account_data)
      end

      now = Time.now
      events = [
        {
          name: 'Web Development Workshop',
          location: 'Room 101',
          start_time: now,
          end_time: now + 3600,
          description: 'Introduction to Web Dev'
        },
        {
          name: 'Security Seminar',
          location: 'Room 202',
          start_time: now + 7200,
          end_time: now + 12_600,
          description: 'Application Security Basics'
        },
        {
          name: 'Database Design Course',
          location: 'Room 303',
          start_time: now + 86_400,
          end_time: now + 90_000,
          description: 'Relational Database Concepts'
        }
      ]

      created_events = events.map { |event_data| TickIt::EventService.create_event(**event_data) }

      student_ids = %w[STU001 STU002 STU003]
      created_events.each do |event|
        student_ids.each do |student_id|
          TickIt::AttendanceRecordService.create_record(
            student_id: student_id,
            event_id: event.id,
            timestamp: event.start_time
          )
        end
      end
    end
  end
end
