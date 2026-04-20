# frozen_string_literal: true

Sequel.migration do
  change do
    # Rename sensitive student columns to encrypted versions
    rename_column :students, :name, :secure_name
    rename_column :students, :email, :secure_email
    rename_column :students, :student_number, :secure_student_number
  end
end
