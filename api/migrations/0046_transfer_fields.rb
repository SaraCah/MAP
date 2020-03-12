Sequel.migration do

  up do
    alter_table(:transfer) do
      add_column(:description, String, text: true, null: true)
      add_column(:remarks, String, text: true, null: true)
      add_column(:previous_system_identifiers, String, null: true)
      add_column(:date_completed, :date, null: true)
    end

    alter_table(:file_issue) do
      add_column(:remarks, String, text: true, null: true)
    end
  end

end
