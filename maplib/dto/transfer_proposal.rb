class TransferProposal
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:title, String, validator: proc {|s| (s.length > 0) ? nil : "Title can't be blank" })
  define_field(:status, String, required: false)
  define_field(:estimated_quantity, String, required: false)
  define_field(:files, [TransferFile], default: [])
  define_field(:series, [TransferProposalSeries], default: [])
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)
  define_field(:transfer_identifier, Integer, required: false)

  def self.from_row(row, transfer_identifier = nil, file_rows = [], series_rows = [])
    new(id: row[:id],
        title: row[:title],
        status: row[:status],
        estimated_quantity: row[:estimated_quantity],
        files: file_rows.map{|file_row| TransferFile.from_row(file_row)},
        series: series_rows.map{|series_row| TransferProposalSeries.from_row(series_row)},
        created_by: row[:created_by],
        create_time: row[:create_time],
        transfer_identifier: transfer_identifier)
  end
end