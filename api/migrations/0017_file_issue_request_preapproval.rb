Sequel.migration do
  up do

    alter_table(:file_issue_request) do
      add_column(:preapprove_quotes, Integer, null: false, default: 0)
    end

  end
end
