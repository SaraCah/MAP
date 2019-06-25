class FileIssue
  include DTO

  STATUS_FILE_ISSUE_INITIATED = 'INITIATED'
  STATUS_RETRIEVAL_IN_PROGRESS = 'IN_PROGRESS'
  STATUS_FILE_ISSUE_ACTIVE = 'ACTIVE'
  STATUS_FILE_ISSUE_COMPLETE = 'COMPLETE'

  STATUS_OPTIONS = [STATUS_FILE_ISSUE_INITIATED, STATUS_RETRIEVAL_IN_PROGRESS,
                    STATUS_FILE_ISSUE_ACTIVE, STATUS_FILE_ISSUE_COMPLETE]

  ISSUE_TYPE_DIGITAL = 'DIGITAL'
  ISSUE_TYPE_PHYSICAL = 'PHYSICAL'

  ISSUE_TYPE_OPTIONS = [ISSUE_TYPE_DIGITAL, ISSUE_TYPE_PHYSICAL]

  define_field(:id, Integer, required: false)
  define_field(:file_issue_request_id, Integer, required: false)
  define_field(:request_type, String)
  define_field(:issue_type, String)
  define_field(:status, String)
  define_field(:checklist_submitted, Boolean, default: false)
  define_field(:checklist_retrieval_started, Boolean, default: false)
  define_field(:checklist_dispatched, Boolean, default: false)
  define_field(:checklist_summary_sent, Boolean, default: false)
  define_field(:checklist_completed, Boolean, default: false)
  define_field(:date_completed, String, required: false)
  define_field(:items, [FileIssueItem], default: [])
  define_field(:urgent, Boolean, default: false)
  define_field(:delivery_location, String)
  define_field(:delivery_authorizer, String)
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)
  define_field(:agency_id, Integer, required: false)
  define_field(:agency_location_id, Integer, required: false)
  define_field(:handle_id, Integer, required: false)

  def self.from_row(row, handle_id = nil, item_rows = [])
    new(id: row[:id],
        file_issue_request_id: row[:file_issue_request_id],
        request_type: row[:request_type],
        issue_type: row[:issue_type],
        status: row[:status],
        checklist_submitted: row[:checklist_submitted] == 1,
        checklist_retrieval_started: row[:checklist_retrieval_started] == 1,
        checklist_dispatched: row[:checklist_dispatched] == 1,
        checklist_summary_sent: row[:checklist_summary_sent] == 1,
        checklist_completed: row[:checklist_completed] == 1,
        urgent: row[:urgent] == 1,
        delivery_location: row[:delivery_location],
        delivery_authorizer: row[:delivery_authorizer],
        agency_id: row[:agency_id],
        agency_location_id: row[:agency_location_id],
        created_by: row[:created_by],
        create_time: row[:create_time],
        lock_version: row[:lock_version],
        items: item_rows.map{|item_row| FileIssueItem.from_row(item_row)},
        handle_id: handle_id)
  end

  def id_for_display
    return '' if new?

    self.class.id_for_display(fetch('id'), fetch('issue_type'))
  end

  def self.id_for_display(id, issue_type)
    "FI#{issue_type[0]}#{id}"
  end

  def all_links_expired?
    fetch('items', []).all? do |item|
      item.expired?
    end
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
