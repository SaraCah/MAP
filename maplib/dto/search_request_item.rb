class SearchRequestItem
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:record_ref, String, required: true)

  def self.from_row(row)
    new(id: row[:id],
        record_ref: "#{row[:aspace_record_type]}:#{row[:aspace_record_id]}")
  end
end
