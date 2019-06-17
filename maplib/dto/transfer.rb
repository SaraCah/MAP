class Transfer
  include DTO

  STATUS_TRANSFER_PROCESS_INITIATED = 'TRANSFER_PROCESS_INITIATED'
  STATUS_TRANSFER_PROCESS_PENDING = 'TRANSFER_PROCESS_PENDING'
  STATUS_TRANSFER_PROCESS_IN_PROGRESS = 'TRANSFER_PROCESS_IN_PROGRESS'
  STATUS_TRANSFER_PROCESS_COMPLETE = 'TRANSFER_PROCESS_COMPLETE'

  STATUS_OPTIONS = [STATUS_TRANSFER_PROCESS_INITIATED,
                    STATUS_TRANSFER_PROCESS_PENDING,
                    STATUS_TRANSFER_PROCESS_IN_PROGRESS,
                    STATUS_TRANSFER_PROCESS_COMPLETE]

  define_field(:id, Integer, required: false)
  define_field(:title, String, required: false)
  define_field(:status, String, required: false)
  define_field(:date_scheduled, Integer, required: false)
  define_field(:date_received, Integer, required: false)
  define_field(:quantity_received, Integer, required: false)

  define_field(:files, [TransferFile], default: [])

  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)

  define_field(:handle_id, Integer, required: false)

  define_field(:agency_id, Integer, required: false)
  define_field(:agency_location_id, Integer, required: false)

  define_field(:checklist_transfer_proposal_approved, Boolean, default: false)
  define_field(:checklist_metadata_received, Boolean, default: false)
  define_field(:checklist_rap_received, Boolean, default: false)
  define_field(:checklist_metadata_approved, Boolean, default: false)
  define_field(:checklist_transfer_received, Boolean, default: false)
  define_field(:checklist_metadata_imported, Boolean, default: false)

  define_field(:transfer_proposal_id, Integer, required: false)

  define_field(:import_job_uri, String, required: false)


  def self.from_row(row, handle = nil, file_rows = [])
    new(id: row[:id],
        title: row[:title],
        status: row[:status],

        checklist_transfer_proposal_approved: row[:checklist_transfer_proposal_approved] == 1,
        checklist_metadata_received: row[:checklist_metadata_received] == 1,
        checklist_rap_received: row[:checklist_rap_received] == 1,
        checklist_metadata_approved: row[:checklist_metadata_approved] == 1,
        checklist_transfer_received: row[:checklist_transfer_received] == 1,
        checklist_metadata_imported: row[:checklist_metadata_imported] == 1,

        date_scheduled: row[:date_scheduled],
        date_received: row[:date_received],
        quantity_received: row[:quantity_received],
        files: file_rows.map{|file_row| TransferFile.from_row(file_row)},
        agency_id: row[:agency_id],
        agency_location_id: row[:agency_location_id],
        created_by: row[:created_by],
        create_time: row[:create_time],
        lock_version: row[:lock_version],

        handle_id: handle,
        transfer_proposal_id: row[:transfer_proposal_id],
       )
  end

  def id_for_display
    return '' if new?

    self.class.id_for_display(fetch('id'))
  end

  def self.id_for_display(id)
    "T#{id}"
  end
end
