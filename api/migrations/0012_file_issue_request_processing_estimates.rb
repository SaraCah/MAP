Sequel.migration do
  up do

    alter_table(:file_issue_request) do
      add_column(:digital_processing_estimate, String, null: true)
      add_column(:physical_processing_estimate, String, null: true)
    end

  end

end
