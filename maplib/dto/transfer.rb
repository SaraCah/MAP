class Transfer
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:title, String, required: false)
  define_field(:status, String, required: false)
  define_field(:scheduled_date, Integer, required: false)
  define_field(:transfer_received_date, Integer, required: false)
  define_field(:quantity_received, Integer, required: false)

  define_field(:files, [TransferFile], default: [])

  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)

  define_field(:transfer_identifier, Integer, required: false)

  def self.from_row(row, transfer_identifier = nil, file_rows = [])
    new(id: row[:id],
        title: row[:title],
        status: row[:status],
        scheduled_date: row[:scheduled_date],
        transfer_received_date: row[:transfer_received_date],
        quantity_received: row[:quantity_received],
        files: file_rows.map{|file_row| TransferFile.from_row(file_row)},
        created_by: row[:created_by],
        create_time: row[:create_time],
        transfer_identifier: transfer_identifier)
  end
end