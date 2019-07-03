require_relative 'transfer_proposal_series'

class TransferProposal
  include DTO

  STATUS_INACTIVE = 'INACTIVE'
  STATUS_ACTIVE = 'ACTIVE'
  STATUS_APPROVED = 'APPROVED'
  STATUS_CANCELLED_BY_QSA = 'CANCELLED_BY_QSA'
  STATUS_CANCELLED_BY_AGENCY = 'CANCELLED_BY_AGENCY'

  STATUS_OPTIONS = [STATUS_INACTIVE,
                    STATUS_ACTIVE,
                    STATUS_APPROVED,
                    STATUS_CANCELLED_BY_QSA,
                    STATUS_CANCELLED_BY_AGENCY]

  define_field(:id, Integer, required: false)
  define_field(:title, String, validator: proc {|s| (s.length > 0) ? nil : "Title can't be blank" })
  define_field(:description, String, required: false)
  define_field(:status, String, required: false, default: 'INACTIVE')
  define_field(:estimated_quantity, String, validator: proc {|s| (s.length > 0) ? nil : "Estimated Quantity can't be blank" })
  define_field(:files, [TransferFile], default: [])
  define_field(:series, [TransferProposalSeries], default: [])
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)
  define_field(:handle_id, Integer, required: false)
  define_field(:agency_id, Integer, required: false)
  define_field(:agency_location_id, Integer, required: false)
  define_field(:transfer_id, Integer, required: false)

  def self.from_row(row, handle = nil, file_rows = [], series_rows = [], transfer_id = nil)
    new(id: row[:id],
        title: row[:title],
        description: row[:description],
        status: row[:status],
        estimated_quantity: row[:estimated_quantity],
        files: file_rows.map{|file_row| TransferFile.from_row(file_row)},
        series: series_rows.map{|series_row| TransferProposalSeries.from_row(series_row)},
        agency_id: row[:agency_id],
        agency_location_id: row[:agency_location_id],
        created_by: row[:created_by],
        create_time: row[:create_time],
        lock_version: row[:lock_version],

        handle_id: handle,
        transfer_id: transfer_id)
  end

  def id_for_display
    return '' if new?

    self.class.id_for_display(fetch('id'))
  end

  def self.id_for_display(id)
    "P#{id}"
  end
end
