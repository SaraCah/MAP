class FileIssueRequest
  include DTO

  DRAFT = 'DRAFT'
  NONE_REQUESTED = 'NONE_REQUESTED'
  QUOTE_REQUESTED = 'QUOTE_REQUESTED'
  QUOTE_PROVIDED = 'QUOTE_PROVIDED'
  QUOTE_ACCEPTED = 'QUOTE_ACCEPTED'
  FILE_ISSUE_CREATED = 'FILE_ISSUE_CREATED'
  CANCELLED_BY_QSA = 'CANCELLED_BY_QSA'
  CANCELLED_BY_AGENCY = 'CANCELLED_BY_AGENCY'

  STATUS_OPTIONS = [
    NONE_REQUESTED, QUOTE_REQUESTED, QUOTE_PROVIDED, QUOTE_ACCEPTED,
    FILE_ISSUE_CREATED, CANCELLED_BY_QSA, CANCELLED_BY_AGENCY,
  ]

  define_field(:id, Integer, required: false)
  define_field(:request_type, String, validator: proc {|s| s.nil? || s.empty? ? "Request Type can't be blank" : nil })
  define_field(:request_notes, String)
  define_field(:digital_request_status, String, required: false, default: NONE_REQUESTED)
  define_field(:physical_request_status, String, required: false, default: NONE_REQUESTED)
  define_field(:urgent, Boolean, default: false)
  define_field(:preapprove_quotes, Boolean, default: false)
  define_field(:draft, Boolean, default: true)
  define_field(:delivery_location, String)
  define_field(:delivery_authorizer, String, required: false)
  define_field(:items, [FileIssueRequestItem], default: [], validator: proc {|arr, dto| arr.empty? && !dto.fetch(:draft, false) ? "Items can't be empty" : nil })
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)
  define_field(:agency_id, Integer, required: false)
  define_field(:agency_location_id, Integer, required: false)
  define_field(:handle_id, Integer, required: false)
  define_field(:version, Integer, required: false)
  define_field(:aspace_digital_quote_id, Integer, required: false)
  define_field(:aspace_physical_quote_id, Integer, required: false)
  define_field(:digital_file_issue_id, Integer, required: false)
  define_field(:physical_file_issue_id, Integer, required: false)
  define_field(:digital_processing_estimate, String, required: false)
  define_field(:physical_processing_estimate, String, required: false)

  def self.from_hash(hash)
    if hash['urgent'] == 'yes'
      hash['urgent'] = true
    end

    if hash['preapprove_quotes'] == 'yes'
      hash['preapprove_quotes'] = true
    end

    if hash['request_type'].nil? || hash['request_type'].strip.empty?
      hash['request_type'] = 'Other'
    end

    super(hash)
  end

  def self.from_row(row, handle_id = nil, item_rows = [], digital_file_issue_id = nil, physical_file_issue_id = nil)
    new(id: row[:id],
        request_type: row[:request_type],
        digital_request_status: row[:digital_request_status],
        physical_request_status: row[:physical_request_status],
        urgent: row[:urgent] == 1,
        preapprove_quotes: row[:preapprove_quotes] == 1,
        draft: row[:draft] == 1,
        delivery_location: row[:delivery_location],
        delivery_authorizer: row[:delivery_authorizer],
        request_notes: row[:request_notes],
        agency_id: row[:agency_id],
        agency_location_id: row[:agency_location_id],
        created_by: row[:created_by],
        create_time: row[:create_time],
        lock_version: row[:lock_version],
        version: row[:version],
        items: item_rows.map{|item_row| FileIssueRequestItem.from_row(item_row)},
        aspace_digital_quote_id: row[:aspace_digital_quote_id],
        aspace_physical_quote_id: row[:aspace_physical_quote_id],
        digital_processing_estimate: row[:digital_processing_estimate] || 'Not Provided',
        physical_processing_estimate: row[:physical_processing_estimate] || 'Not Provided',
        handle_id: handle_id,
        digital_file_issue_id: digital_file_issue_id,
        physical_file_issue_id: physical_file_issue_id)
  end

  def can_edit?
    return false if fetch('physical_request_status') == CANCELLED_BY_AGENCY && fetch('digital_request_status') == CANCELLED_BY_AGENCY
    return false if fetch('physical_request_status') == CANCELLED_BY_QSA && fetch('digital_request_status') == CANCELLED_BY_QSA

    return false if [QUOTE_ACCEPTED, FILE_ISSUE_CREATED].include?(fetch('digital_request_status'))
    return false if [QUOTE_ACCEPTED, FILE_ISSUE_CREATED].include?(fetch('physical_request_status'))

    return false if [CANCELLED_BY_QSA, CANCELLED_BY_AGENCY].include?(fetch('digital_request_status')) && fetch('physical_request_status') == NONE_REQUESTED
    return false if [CANCELLED_BY_QSA, CANCELLED_BY_AGENCY].include?(fetch('physical_request_status')) && fetch('digital_request_status') == NONE_REQUESTED

    true
  end

  def show_digital_quote?
    fetch('aspace_digital_quote_id', false) && [FileIssueRequest::QUOTE_PROVIDED, FileIssueRequest::QUOTE_ACCEPTED, FileIssueRequest::FILE_ISSUE_CREATED].include?(fetch('digital_request_status', false))
  end

  def show_physical_quote?
    fetch('aspace_physical_quote_id', false) && [FileIssueRequest::QUOTE_PROVIDED, FileIssueRequest::QUOTE_ACCEPTED, FileIssueRequest::FILE_ISSUE_CREATED].include?(fetch('physical_request_status', false))
  end

  def id_for_display
    return '' if new?

    self.class.id_for_display(fetch('id'))
  end

  def self.id_for_display(id)
    "R#{id}"
  end

  def is_delivery_authorizer_required?
    return false if ['READING_ROOM', 'AGENCY_ARRANGED_COURIER'].include?(fetch('delivery_location', nil))
    return false unless fetch('items').any?{|item| item.fetch('request_type').downcase == 'physical'}

    s = fetch('delivery_authorizer', nil)

    s.nil? || s.empty?
  end

  def available_request_types
    AppConfig[:file_issue_request_types]
  end

  def request_type_display_string
    if AppConfig[:file_issue_request_types].include?(fetch('request_type'))
      fetch('request_type')
    elsif fetch('request_type') == 'Other'
      fetch('request_type')
    else
      ['Other', fetch('request_type')].join(' - ')
    end
  end
end
