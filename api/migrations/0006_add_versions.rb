Sequel.migration do
  up do

    [:agency_location, :user]
    .each do |table_name|
      alter_table(table_name) do
        add_column(:lock_version, Integer, null: false, default: 0)
      end
    end

    alter_table(:file_issue_request) do
      add_column(:version, Integer, null: false, default: 0)
    end

  end

end
