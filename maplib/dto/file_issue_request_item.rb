class FileIssueRequestItem
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:record_ref, String, required: true)
  define_field(:request_type, String, required: true)
  define_field(:record_details, String, required: false)
  define_field(:record_label, String, required: false)

  def self.from_row(row)
    new(id: row[:id],
        record_ref: "#{row[:aspace_record_type]}:#{row[:aspace_record_id]}",
        request_type: row[:request_type],
        record_details: row[:record_details])
  end
end
