class Transfer
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:title, String, validator: proc {|s| (s.length > 0) ? nil : "Title can't be blank" })
  define_field(:csv_filename, String, required: false)
  define_field(:csv, String, required: false)
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)

  def self.from_row(row)
    new(id: row[:id],
        title: row[:title],
        status: row[:status],
        csv_filename: row[:csv_filename],
        created_by: row[:created_by],
        create_time: row[:create_time])
  end
end