Sequel.migration do
  up do

    # Capitalise for match with new select value
    self[:file_issue_request]
      .filter(:request_type => 'other')
      .update(:request_type => 'Other',
              :system_mtime => Time.now)
    self[:file_issue]
      .filter(:request_type => 'other')
      .update(:request_type => 'Other',
              :system_mtime => Time.now)
  end
end
