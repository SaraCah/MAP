class SearchRequest
  include DTO

  INACTIVE = 'INACTIVE'
  SUBMITTED = 'SUBMITTED'
  OPEN = 'OPEN'
  CLOSED = 'CLOSED'
  CANCELLED_BY_QSA = 'CANCELLED_BY_QSA'
  CANCELLED_BY_AGENCY = 'CANCELLED_BY_AGENCY'

  STATUS_OPTIONS = [
    INACTIVE, SUBMITTED, OPEN, CLOSED,
    CANCELLED_BY_QSA, CANCELLED_BY_AGENCY,
  ]

  define_field(:id, Integer, required: false)
  define_field(:details, String, validator: proc {|s| s.nil? || s.empty? ? "Details can't be blank" : nil })
  define_field(:date_details, String)
  define_field(:purpose, String)
  define_field(:status, String, required: false, default: INACTIVE)
  define_field(:draft, Boolean, default: true)
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)
  define_field(:agency_id, Integer, required: false)
  define_field(:agency_location_id, Integer, required: false)
  define_field(:handle_id, Integer, required: false)
  define_field(:version, Integer, required: false)
  define_field(:aspace_quote_id, Integer, required: false)
  define_field(:files, [SearchRequestFile], default: [])


  def self.from_row(row, handle_id = nil, file_rows = [])
    new(id: row[:id],
        details: row[:details],
        date_details: row[:date_details],
        purpose: row[:purpose],
        status: row[:status],
        draft: row[:draft] == 1,
        aspace_quote_id: row[:aspace_quote_id],
        agency_id: row[:agency_id],
        agency_location_id: row[:agency_location_id],
        created_by: row[:created_by],
        create_time: row[:create_time],
        lock_version: row[:lock_version],
        version: row[:version],
        files: file_rows.map{|file_row| SearchRequestFile.from_row(file_row)},
        handle_id: handle_id)
  end


  def self.from_hash(hash)
    if hash['purpose'].nil? || hash['purpose'].strip.empty?
      hash['purpose'] = 'Other'
    end

    super(hash)
  end


  def can_edit?
    return false if fetch('status') == CANCELLED_BY_AGENCY
    return false if fetch('status') == CANCELLED_BY_QSA
    return false if fetch('status') == CLOSED

    true
  end

  def id_for_display
    return '' if new?

    self.class.id_for_display(fetch('id'))
  end

  def self.id_for_display(id)
    "SR#{id}"
  end

  def has_quote?
    fetch('aspace_quote_id', false)
  end

  def can_be_cancelled?
    [INACTIVE, SUBMITTED].include?(fetch('status'))
  end

  def available_purposes
    ['RTI', 'Redress']
  end

  def purpose_for_display
    return '' if fetch('purpose', nil).nil?

    if available_purposes.include?(fetch('purpose'))
      fetch('purpose')
    elsif fetch('purpose') == 'Other'
      fetch('purpose')
    else
      ['Other', fetch('purpose')].join(' - ')
    end
  end
end
