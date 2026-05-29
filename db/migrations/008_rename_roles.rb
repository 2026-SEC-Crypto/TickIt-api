# frozen_string_literal: true

Sequel.migration do
  up do
    run "UPDATE accounts SET role = 'regular' WHERE role = 'member'"
    run "UPDATE accounts SET role = 'teacher' WHERE role = 'organizer'"
  end

  down do
    run "UPDATE accounts SET role = 'member' WHERE role = 'regular'"
    run "UPDATE accounts SET role = 'organizer' WHERE role = 'teacher'"
  end
end
