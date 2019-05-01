class TransferProposal
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:title, String, validator: proc {|s| (s.length > 0) ? nil : "Title can't be blank" })
  define_field(:status, String, required: false)
  define_field(:files, [TransferFile], default: [])
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)

  def self.from_row(row, file_rows = [])
    new(id: row[:id],
        title: row[:title],
        status: row[:status],
        files: file_rows.map{|file_row| TransferFile.from_row(file_row)},
        created_by: row[:created_by],
        create_time: row[:create_time])
  end
end