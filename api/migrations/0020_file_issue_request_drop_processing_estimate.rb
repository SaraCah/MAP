Sequel.migration do
  up do
    alter_table(:file_issue_request) do
      drop_column(:digital_processing_estimate)
      drop_column(:physical_processing_estimate)
    end
  end
end
