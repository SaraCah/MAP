class FileIssueRequestItem
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:record_uri, String, required: true)
  define_field(:request_type, String, required: true)

  def self.from_row(row)
    new(id: row[:id],
        record_uri: row[:record_uri],
        request_type: row[:request_type])
  end
end
