# frozen_string_literal: true

# Loaded automatically by `rake console` (pry).
# Auto-formats Sequel model arrays as readable tables via table_print.
# Dev-only convenience; has no effect on the app or tests.

require 'table_print'

# Per-model default columns, so `tp TickIt::Student.all` and bare
# `TickIt::Student.all` both show sensible, non-overflowing output.
if defined?(TickIt::Student)
  tp.set TickIt::Student, :id, :name, :email, :student_number
  tp.set TickIt::Event, :id, :name, :location, :start_time, :end_time
  tp.set TickIt::AttendanceRecord, :id, :student_id, :event_id, :status, :check_in_time
end

# Make `TickIt::Student.all` (and other model arrays) auto-render as tables
# in pry, the way Hirb used to. Falls back to the default printer for
# everything else.
#
# NOTE: TablePrint::Printer.table_print returns a STRING and does not
# write to stdout itself — only the top-level `tp` helper puts it.
# Inside a Pry.config.print hook we have to write to `output` ourselves.
old_print = Pry.config.print
Pry.config.print = proc do |output, value, *rest|
  if value.is_a?(Array) && value.first.is_a?(Sequel::Model)
    output.puts TablePrint::Printer.table_print(value)
  else
    old_print.call(output, value, *rest)
  end
end

puts 'table_print enabled - Sequel model arrays auto-render as tables.'
