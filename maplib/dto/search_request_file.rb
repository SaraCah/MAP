class SearchRequestFile
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:filename, String)
  define_field(:key, String)
  define_field(:mime_type, String)
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)

  def self.from_row(row)
    new(id: row[:id],
        filename: row[:filename],
        key: row[:key],
        mime_type: row[:mime_type],
        created_by: row[:created_by],
        create_time: row[:create_time])
  end
end
