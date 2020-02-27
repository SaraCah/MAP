Sequel.migration do

  up do
    # 'National Redress Scheme' becomes 'National Redress Scheme or related'
    self[:file_issue_request]
      .filter(:request_type => 'National Redress Scheme')
      .update(:request_type => 'National Redress Scheme or related')

    self[:file_issue]
      .filter(:request_type => 'National Redress Scheme')
      .update(:request_type => 'National Redress Scheme or related')
  end

end
