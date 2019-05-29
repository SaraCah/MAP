Sequel.migration do
  up do

    alter_table(:file_issue) do
      add_column(:checklist_retrieval_started, Integer, null: false, default: 0)
    end

  end

end
