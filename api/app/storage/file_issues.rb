class FileIssues < BaseStorage

  NON_REQUESTED = 'NON_REQUESTED'
  QUOTE_REQUESTED = 'QUOTE_REQUESTED'
  QUOTE_PROVIDED = 'QUOTE_PROVIDED'
  QUOTE_ACCEPTED = 'QUOTE_ACCEPTED'
  FILE_ISSUE_CREATED = 'FILE_ISSUE_CREATED'
  CANCELLED_BY_QSA = 'CANCELLED_BY_QSA'
  CANCELLED_BY_AGENCY = 'CANCELLED_BY_AGENCY'

  def self.requests(page, page_size)
    dataset = db[:file_issue_request]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:file_issue_request][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:file_issue_request][:agency_location_id] => current_location.id)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    dataset = dataset.order(Sequel.desc(Sequel[:file_issue_request][:create_time]))

    PagedResults.new(dataset.map{|row| FileIssueRequest.from_row(row)},
                     page,
                     max_page)
  end


  def self.create_request_from_dto(file_issue_request)
    errors = []

    digital_request_status = NON_REQUESTED
    physical_request_status = NON_REQUESTED
    if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'DIGITAL'}
      digital_request_status = QUOTE_REQUESTED
    end
    if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'PHYSICAL'}
      physical_request_status = QUOTE_REQUESTED
    end

    file_issue_request_id = db[:file_issue_request].insert(request_type: file_issue_request.fetch('request_type'),
                                                           urgent: file_issue_request.fetch('urgent') ? 1 : 0,
                                                           deliver_to_reading_room: file_issue_request.fetch('deliver_to_reading_room') ? 1 : 0,
                                                           delivery_authorizer: file_issue_request.fetch('delivery_authorizer', nil),
                                                           request_notes: file_issue_request.fetch('request_notes', nil),
                                                           digital_request_status: digital_request_status,
                                                           physical_request_status: physical_request_status,
                                                           agency_id: Ctx.get.current_location.agency_id,
                                                           agency_location_id: Ctx.get.current_location.id,
                                                           created_by: Ctx.username,
                                                           create_time: java.lang.System.currentTimeMillis,
                                                           system_mtime: Time.now)

    db[:handle].insert(file_issue_request_id: file_issue_request_id)

    file_issue_request.fetch('items').each do |item|
      (record_type, record_id) = item.fetch('record_ref').split(':')
      db[:file_issue_request_item]
        .insert(file_issue_request_id: file_issue_request_id,
                aspace_record_type: record_type,
                aspace_record_id: record_id,
                request_type: item.fetch('request_type'),
                record_details: item.fetch('record_details'))
    end

    errors
  end

  def self.request_dto_for(file_issue_request_id)
    handle_id = db[:handle][file_issue_request_id: file_issue_request_id][:id]
    FileIssueRequest.from_row(db[:file_issue_request][id: file_issue_request_id],
                              handle_id,
                              db[:file_issue_request_item].filter(file_issue_request_id: file_issue_request_id))
  end

  def self.update_request_from_dto(file_issue_request)
    errors = []

    file_issue_request_id = file_issue_request.fetch('id')

    digital_request_status = NON_REQUESTED
    physical_request_status = NON_REQUESTED
    if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'DIGITAL'}
      digital_request_status = QUOTE_REQUESTED
    end
    if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'PHYSICAL'}
      physical_request_status = QUOTE_REQUESTED
    end

    db[:file_issue_request]
      .filter(id: file_issue_request_id)
      .update(request_type: file_issue_request.fetch('request_type'),
              urgent: file_issue_request.fetch('urgent') ? 1 : 0,
              digital_request_status: digital_request_status, # assume any change forces a quote redo
              physical_request_status: physical_request_status, # assume any change forces a quote redo
              deliver_to_reading_room: file_issue_request.fetch('deliver_to_reading_room') ? 1 : 0,
              delivery_authorizer: file_issue_request.fetch('delivery_authorizer', nil),
              request_notes: file_issue_request.fetch('request_notes', nil),
              system_mtime: Time.now)

    # FIXME update request has changed? So need to drop previous quote as we're
    # back to QUOTE_REQUEST_SUBMITTED.

    db[:file_issue_request_item]
      .filter(file_issue_request_id: file_issue_request_id)
      .delete

    file_issue_request.fetch('items').each do |item|
      (record_type, record_id) = item.fetch('record_ref').split(':')
      db[:file_issue_request_item]
        .insert(file_issue_request_id: file_issue_request_id,
                aspace_record_type: record_type,
                aspace_record_id: record_id,
                request_type: item.fetch('request_type'),
                record_details: item.fetch('record_details'))
    end

    errors
  end
end
