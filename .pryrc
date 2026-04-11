# frozen_string_literal: true

# Per course: enable Hirb for tabular output in Pry (e.g. `Student.all` in `rake console`)
begin
  require 'hirb'
  Hirb.enable
rescue LoadError
  warn '[.pryrc] hirb not installed; run `bundle install`'
end
