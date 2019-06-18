Sequel.migration do
  up do
    alter_table(:file_issue_request) do
      add_column(:draft, Integer, null: false, default: 0)
    end
  end
end
