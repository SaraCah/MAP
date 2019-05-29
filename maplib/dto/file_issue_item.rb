class FileIssueItem
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:record_ref, String, required: true)
  define_field(:record_details, String, required: false)
  define_field(:record_label, String, required: false)
  define_field(:dispatch_date, Date, required: false)
  define_field(:expiry_date, Date, required: false)
  define_field(:returned_date, Date, required: false)

  def self.from_row(row)
    new(id: row[:id],
        record_ref: "#{row[:aspace_record_type]}:#{row[:aspace_record_id]}",
        record_details: row[:record_details],
        dispatch_date: row[:dispatch_date],
        expiry_date: row[:expiry_date],
        returned_date: row[:returned_date])
  end

  def overdue?
    return false if fetch('dispatch_date',nil).nil?
    return false if fetch('expiry_date',nil).nil?
    return false unless fetch('returned_date',nil).nil?

    fetch('expiry_date') < Date.today
  end
end
