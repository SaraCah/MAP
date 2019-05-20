class FileIssueRequest
  include DTO

  NON_REQUESTED = 'NON_REQUESTED'
  QUOTE_REQUESTED = 'QUOTE_REQUESTED'
  QUOTE_PROVIDED = 'QUOTE_PROVIDED'
  QUOTE_ACCEPTED = 'QUOTE_ACCEPTED'
  FILE_ISSUE_CREATED = 'FILE_ISSUE_CREATED'
  CANCELLED_BY_QSA = 'CANCELLED_BY_QSA'
  CANCELLED_BY_AGENCY = 'CANCELLED_BY_AGENCY'

  define_field(:id, Integer, required: false)
  define_field(:request_type, String)
  define_field(:request_notes, String)
  define_field(:digital_request_status, String, required: false, default: NON_REQUESTED)
  define_field(:physical_request_status, String, required: false, default: NON_REQUESTED)
  define_field(:urgent, Boolean, default: false)
  define_field(:deliver_to_reading_room, Boolean, default: false)
  define_field(:delivery_authorizer, String, validator: proc {|s, request| !request.fetch('deliver_to_reading_room') && (s.nil? || s.empty?) ? "Delivery Authorizer can't be blank" : nil })
  define_field(:items, [FileIssueRequestItem], default: [], validator: proc {|arr| arr.empty? ? "Items can't be empty" : nil })
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)
  define_field(:agency_id, Integer, required: false)
  define_field(:agency_location_id, Integer, required: false)
  define_field(:handle_id, Integer, required: false)

  def self.from_hash(hash)
    if ['yes', 'no'].include?(hash[:deliver_to_reading_room])
      hash[:deliver_to_reading_room] = (hash[:deliver_to_reading_room] == 'yes')
    end

    if hash[:urgent] == 'yes'
      hash[:urgent] = true
    end

    super(hash)
  end

  def self.from_row(row, handle_id = nil, item_rows = [])
    new(id: row[:id],
        request_type: row[:request_type],
        digital_request_status: row[:digital_request_status],
        physical_request_status: row[:physical_request_status],
        urgent: row[:urgent] == 1,
        deliver_to_reading_room: row[:deliver_to_reading_room] == 1,
        delivery_authorizer: row[:delivery_authorizer],
        request_notes: row[:request_notes],
        agency_id: row[:agency_id],
        agency_location_id: row[:agency_location_id],
        created_by: row[:created_by],
        create_time: row[:create_time],
        items: item_rows.map{|item_row| FileIssueRequestItem.from_row(item_row)},
        handle_id: handle_id)
  end

  def can_edit?
    return false if [QUOTE_ACCEPTED, FILE_ISSUE_CREATED].include?(fetch('digital_request_status'))
    return false if [QUOTE_ACCEPTED, FILE_ISSUE_CREATED].include?(fetch('physical_request_status'))

    return false if [CANCELLED_BY_QSA, CANCELLED_BY_AGENCY].include?(fetch('digital_request_status')) && fetch('physical_request_status') == NON_REQUESTED 
    return false if [CANCELLED_BY_QSA, CANCELLED_BY_AGENCY].include?(fetch('physical_request_status')) && fetch('digital_request_status') == NON_REQUESTED 

    true
  end

  def id_for_display
    return '' if new?

    self.class.id_for_display(fetch('id'))
  end

  def self.id_for_display(id)
    "R#{id}"
  end
end
