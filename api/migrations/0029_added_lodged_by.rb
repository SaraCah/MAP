Sequel.migration do
  up do

    alter_table(:transfer_proposal) do
      add_column(:lodged_by, String, null: true)
    end

    alter_table(:transfer) do
      add_column(:lodged_by, String, null: true)
    end

    alter_table(:search_request) do
      add_column(:lodged_by, String, null: true)
    end

    alter_table(:file_issue_request) do
      add_column(:lodged_by, String, null: true)
    end

    alter_table(:file_issue) do
      add_column(:lodged_by, String, null: true)
    end

  end
end
