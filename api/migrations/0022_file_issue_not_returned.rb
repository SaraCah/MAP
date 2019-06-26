Sequel.migration do
  up do
    alter_table(:file_issue_item) do
      add_column(:not_returned, Integer, :null => false, :default => 0)
      add_column(:not_returned_note, String, :text => true)
    end
  end
end
