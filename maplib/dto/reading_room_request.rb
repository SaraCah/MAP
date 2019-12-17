class ReadingRoomRequest
  include DTO

  STATUS_PENDING = 'PENDING'
  STATUS_BEING_RETRIEVED = 'BEING_RETRIEVED'
  STATUS_DELIVERED_TO_READING_ROOM = 'DELIVERED_TO_READING_ROOM'
  STATUS_DELIVERED_TO_ARCHIVIST = 'DELIVERED_TO_ARCHIVIST'
  STATUS_DELIVERED_TO_CONSERVATION = 'DELIVERED_TO_CONSERVATION'
  STATUS_COMPLETE = 'COMPLETE'
  STATUS_CANCELLED_BY_AGENCY = 'CANCELLED_BY_RESEARCHER'
  STATUS_CANCELLED_BY_QSA = 'CANCELLED_BY_QSA'

  STATUS_OPTIONS = [STATUS_PENDING,
                    STATUS_BEING_RETRIEVED,
                    STATUS_DELIVERED_TO_READING_ROOM,
                    STATUS_DELIVERED_TO_ARCHIVIST,
                    STATUS_DELIVERED_TO_CONSERVATION,
                    STATUS_COMPLETE,
                    STATUS_CANCELLED_BY_AGENCY,
                    STATUS_CANCELLED_BY_QSA]

  define_field(:id, Integer, required: false)
  define_field(:status, String, required: false)
  define_field(:date_required, String, validator: proc {|s| s.nil? || s.empty? ? "Date Required can't be blank" : nil })
  define_field(:time_required, String, validator: proc {|s| s.nil? || s.empty? ? "Time Required can't be blank" : nil })
  define_field(:record_ref, String, required: false)
  define_field(:created_by, String, required: false)
  define_field(:modified_by, String, required: false)
  define_field(:create_time, Integer, required: false)
  define_field(:modified_time, Integer, required: false)
  define_field(:agency_id, Integer, required: false)
  define_field(:agency_location_id, Integer, required: false)
  define_field(:handle_id, Integer, required: false)

  def self.from_row(row, handle_id = nil, item_rows = [])
    new(id: row[:id],
        status: row[:status],
        date_required: row[:date_required],
        time_required: row[:time_required],
        agency_id: row[:agency_id],
        agency_location_id: row[:agency_location_id],
        created_by: row[:created_by],
        create_time: row[:create_time],
        modified_by: row[:modified_by],
        modified_time: row[:modified_time],
        lock_version: row[:lock_version],
        record_ref: row[:item_id],
        handle_id: handle_id)
  end

  def id_for_display
    return '' if new?

    self.class.id_for_display(fetch('id'))
  end

  def self.id_for_display(id)
    "RR#{id}"
  end
end
