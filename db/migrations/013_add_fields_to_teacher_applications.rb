# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:teacher_applications) do
      add_column :real_name, String
      add_column :organization, String
      add_column :school_email, String
      add_column :notes, String
      add_column :rejection_reason, String
    end
  end
end
