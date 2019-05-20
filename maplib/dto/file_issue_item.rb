class FileIssueItem
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:record_ref, String, required: true)
  define_field(:record_details, String, required: false)
  define_field(:record_label, String, required: false)
  define_field(:dispatch_date, String, required: false)
  define_field(:loan_expiry_date, String, required: false)
  define_field(:returned_date, String, required: false)
  define_field(:overdue, Boolean, default: false)
  define_field(:extension_requested, Boolean, default: false)
  define_field(:requested_extension_date, String, default: false)

  def self.from_row(row)
    new(id: row[:id],
        record_ref: "#{row[:aspace_record_type]}:#{row[:aspace_record_id]}",
        record_details: row[:record_details],
        dispatch_date: row[:dispatch_date],
        loan_expiry_date: row[:dispatch_date],
        returned_date: row[:dispatch_date],
        extension_requested: row[:extension_requested] == 1,
        requested_extension_date: row[:requested_extension_date])
  end
end
