class Transfer
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:title, String, required: false)
  define_field(:checklist_status, String, required: false)
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

  def self.from_row(row, handle = nil, file_rows = [])
    new(id: row[:id],
        title: row[:title],
        status: row[:status],
        checklist_status: row[:checklist_status],
        date_scheduled: row[:date_scheduled],
        date_received: row[:date_received],
        quantity_received: row[:quantity_received],
        files: file_rows.map{|file_row| TransferFile.from_row(file_row)},
        agency_id: row[:agency_id],
        agency_location_id: row[:agency_location_id],
        created_by: row[:created_by],
        create_time: row[:create_time],
        handle_id: handle)
  end
end
