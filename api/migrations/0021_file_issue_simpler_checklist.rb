Sequel.migration do
  up do
    alter_table(:file_issue) do
      drop_column(:checklist_retrieval_started)
      drop_column(:checklist_summary_sent)
    end

    self[:file_issue]
      .filter(:status => 'IN_PROGRESS')
      .update(:status => 'INITIATED',
              :system_mtime => Time.now)
  end
end
