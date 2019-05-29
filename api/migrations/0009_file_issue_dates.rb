Sequel.migration do
  up do

    alter_table(:file_issue_item) do
      set_column_type(:dispatch_date, :date)
      set_column_type(:expiry_date, :date)
      set_column_type(:returned_date, :date)

      drop_column(:overdue) # instead calculate using dates
    end

  end

end
