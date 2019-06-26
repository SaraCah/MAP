class FileIssueItem
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:record_ref, String, required: true)
  define_field(:record_details, String, required: false)
  define_field(:record_label, String, required: false)
  define_field(:dispatch_date, Date, required: false)
  define_field(:expiry_date, Date, required: false)
  define_field(:returned_date, Date, required: false)
  define_field(:file_issue_token, String, required: false)
  define_field(:not_returned, Boolean, required: false)
  define_field(:not_returned_note, String, required: false)

  def self.from_row(row)
    new(id: row[:id],
        record_ref: "#{row[:aspace_record_type]}:#{row[:aspace_record_id]}",
        record_details: row[:record_details],
        dispatch_date: row[:dispatch_date],
        expiry_date: row[:expiry_date],
        returned_date: row[:returned_date],
        file_issue_token: row[:file_issue_token],
        not_returned: row[:not_returned] == 1,
        not_returned_note: row[:not_returned_note],
       )
  end

  def overdue?
    return false if fetch('dispatch_date',nil).nil?
    return false if fetch('expiry_date',nil).nil?
    return false unless fetch('returned_date',nil).nil?
    return false if fetch('not_returned', false)

    fetch('expiry_date') < Date.today
  end

  def expired?
    fetch('expiry_date', false) && fetch('expiry_date') < Date.today
  end

  def downloadable?
    return false if !fetch('file_issue_token', nil)
    return false if fetch('dispatch_date', nil).nil?
    return false if fetch('dispatch_date') > Date.today
    return false if expired?

    true
  end
end
