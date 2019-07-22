class FileIssues < BaseStorage

  REQUEST_SORT_OPTIONS = {
    'id_asc' => Sequel.asc(Sequel[:file_issue_request][:id]),
    'id_desc' => Sequel.desc(Sequel[:file_issue_request][:id]),
    'request_type_asc' => Sequel.asc(Sequel.function(:lower, Sequel[:file_issue_request][:request_type])),
    'request_type_desc' => Sequel.desc(Sequel.function(:lower, Sequel[:file_issue_request][:request_type])),
    'digital_request_status_asc' => Sequel.asc(Sequel[:file_issue_request][:digital_request_status]),
    'digital_request_status_desc' => Sequel.desc(Sequel[:file_issue_request][:digital_request_status]),
    'physical_request_status_asc' => Sequel.asc(Sequel[:file_issue_request][:physical_request_status]),
    'physical_request_status_desc' => Sequel.desc(Sequel[:file_issue_request][:physical_request_status]),
    'created_asc' => Sequel.asc(Sequel[:file_issue_request][:create_time]),
    'created_desc' => Sequel.desc(Sequel[:file_issue_request][:create_time]),
  }

  FILE_ISSUE_SORT_OPTIONS = {
    'id_asc' => Sequel.asc(Sequel[:file_issue][:id]),
    'id_desc' => Sequel.desc(Sequel[:file_issue][:id]),
    'request_type_asc' => Sequel.asc(Sequel.function(:lower, Sequel[:file_issue][:request_type])),
    'request_type_desc' => Sequel.desc(Sequel.function(:lower, Sequel[:file_issue][:request_type])),
    'issue_type_asc' => Sequel.asc(Sequel.function(:lower, Sequel[:file_issue][:issue_type])),
    'issue_type_desc' => Sequel.desc(Sequel.function(:lower, Sequel[:file_issue][:issue_type])),
    'status_asc' => Sequel.asc(Sequel[:file_issue][:status]),
    'status_desc' => Sequel.desc(Sequel[:file_issue][:status]),
    'created_asc' => Sequel.asc(Sequel[:file_issue][:create_time]),
    'created_desc' => Sequel.desc(Sequel[:file_issue][:create_time]),
  }

  def self.requests(page, page_size, digital_request_status = nil, physical_request_status = nil, sort = nil)
    dataset = db[:file_issue_request]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:file_issue_request][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:file_issue_request][:agency_location_id] => current_location.id)
    end

    if digital_request_status && FileIssueRequest::STATUS_OPTIONS.include?(digital_request_status)
      dataset = dataset.filter(Sequel[:file_issue_request][:digital_request_status] => digital_request_status)
    end

    if physical_request_status && FileIssueRequest::STATUS_OPTIONS.include?(physical_request_status)
      dataset = dataset.filter(Sequel[:file_issue_request][:physical_request_status] => physical_request_status)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    sort_by = REQUEST_SORT_OPTIONS.fetch(sort, REQUEST_SORT_OPTIONS.fetch('id_desc'))

    dataset = dataset.order(sort_by)

    PagedResults.new(dataset.map{|row| FileIssueRequest.from_row(row)},
                     page,
                     max_page)
  end


  def self.create_request_from_dto(file_issue_request)
    errors = []

    digital_request_status = FileIssueRequest::NONE_REQUESTED
    physical_request_status = FileIssueRequest::NONE_REQUESTED
    unless file_issue_request.fetch('draft')
      digital_request_status = FileIssueRequest::NONE_REQUESTED
      physical_request_status = FileIssueRequest::NONE_REQUESTED
      if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'DIGITAL'}
        digital_request_status = FileIssueRequest::QUOTE_REQUESTED

        if file_issue_request.fetch('preapprove_quotes')
          digital_request_status = FileIssueRequest::QUOTE_ACCEPTED
        end
      end
      if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'PHYSICAL'}
        physical_request_status = FileIssueRequest::QUOTE_REQUESTED

        if file_issue_request.fetch('preapprove_quotes')
          physical_request_status = FileIssueRequest::QUOTE_ACCEPTED
        end
      end
    end

    lodged_by = nil
    unless file_issue_request.fetch('draft')
      username = Users.name_for(Ctx.username)
      position = Ctx.get.permissions.position_for(Ctx.get.current_location.agency.fetch('id'), Ctx.get.current_location.id)
      lodged_by = "%s (%s)" % [username, position]
    end

    file_issue_request_id = db[:file_issue_request].insert(request_type: file_issue_request.fetch('request_type'),
                                                           urgent: file_issue_request.fetch('urgent') ? 1 : 0,
                                                           preapprove_quotes: file_issue_request.fetch('preapprove_quotes') ? 1 : 0,
                                                           draft: file_issue_request.fetch('draft') ? 1 : 0,
                                                           delivery_location: file_issue_request.fetch('delivery_location'),
                                                           delivery_authorizer: file_issue_request.fetch('delivery_authorizer', nil),
                                                           request_notes: file_issue_request.fetch('request_notes', nil),
                                                           digital_request_status: digital_request_status,
                                                           physical_request_status: physical_request_status,
                                                           agency_id: Ctx.get.current_location.agency_id,
                                                           agency_location_id: Ctx.get.current_location.id,
                                                           lodged_by: lodged_by,
                                                           created_by: Ctx.username,
                                                           create_time: java.lang.System.currentTimeMillis,
                                                           modified_by: Ctx.username,
                                                           modified_time: java.lang.System.currentTimeMillis,
                                                           version: 1,
                                                           system_mtime: Time.now)

    db[:handle].insert(file_issue_request_id: file_issue_request_id)

    verify_item_access!(file_issue_request.fetch('items', []))

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
    handle_row = db[:handle][file_issue_request_id: file_issue_request_id]

    return nil unless handle_row

    handle_id = handle_row[:id]
    row = db[:file_issue_request][id: file_issue_request_id]

    digital_request_id = nil
    physical_request_id = nil

    db[:file_issue]
      .filter(file_issue_request_id: file_issue_request_id)
      .map do |file_issue_row|
      if file_issue_row[:issue_type] == FileIssue::ISSUE_TYPE_DIGITAL
       digital_request_id = file_issue_row[:id]
      elsif file_issue_row[:issue_type] == FileIssue::ISSUE_TYPE_PHYSICAL
        physical_request_id = file_issue_row[:id]
      end
    end
    
    FileIssueRequest.from_row(row,
                              handle_id,
                              db[:file_issue_request_item].filter(file_issue_request_id: file_issue_request_id),
                              digital_request_id,
                              physical_request_id)
  end

  def self.update_request_from_dto(file_issue_request)
    errors = []

    file_issue_request_id = file_issue_request.fetch('id')

    digital_request_status = FileIssueRequest::NONE_REQUESTED
    physical_request_status = FileIssueRequest::NONE_REQUESTED
    unless file_issue_request.fetch('draft')
      digital_request_status = FileIssueRequest::NONE_REQUESTED
      physical_request_status = FileIssueRequest::NONE_REQUESTED
      if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'DIGITAL'}
        digital_request_status = FileIssueRequest::QUOTE_REQUESTED

        if file_issue_request.fetch('preapprove_quotes')
          digital_request_status = FileIssueRequest::QUOTE_ACCEPTED
        end
      end
      if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'PHYSICAL'}
        physical_request_status = FileIssueRequest::QUOTE_REQUESTED

        if file_issue_request.fetch('preapprove_quotes')
          physical_request_status = FileIssueRequest::QUOTE_ACCEPTED
        end
      end
    end

    update_data = {
      request_type: file_issue_request.fetch('request_type'),
      urgent: file_issue_request.fetch('urgent') ? 1 : 0,
      preapprove_quotes: file_issue_request.fetch('preapprove_quotes') ? 1 : 0,
      draft: file_issue_request.fetch('draft') ? 1 : 0,
      digital_request_status: digital_request_status, # assume any change forces a quote redo
      physical_request_status: physical_request_status, # assume any change forces a quote redo
      delivery_location: file_issue_request.fetch('delivery_location'),
      delivery_authorizer: file_issue_request.fetch('delivery_authorizer', nil),
      request_notes: file_issue_request.fetch('request_notes', nil),
      version: file_issue_request.fetch('version') + 1,
      lock_version: file_issue_request.fetch('lock_version') + 1,
      modified_by: Ctx.username,
      modified_time: java.lang.System.currentTimeMillis,
      system_mtime: Time.now
    }

    unless file_issue_request.fetch('draft') && db[:file_issue_request][id: file_issue_request_id][:draft] == 1
      username = Users.name_for(Ctx.username)
      position = Ctx.get.permissions.position_for(Ctx.get.current_location.agency.fetch('id'), Ctx.get.current_location.id)
      update_data[:lodged_by] = "%s (%s)" % [username, position]
    end
      
    updated = db[:file_issue_request]
                .filter(id: file_issue_request_id)
                .filter(lock_version: file_issue_request.fetch('lock_version'))
                .update(update_data)

    raise StaleRecordException.new if updated == 0

    existing_item_refs = db[:file_issue_request_item]
                       .filter(:file_issue_request_id => file_issue_request_id)
                       .select(:aspace_record_type, :aspace_record_id)
                       .map {|row|
      '%s:%s' % [row[:aspace_record_type], row[:aspace_record_id]]
    }

    # Identify newly added items and make sure access is OK.
    verify_item_access!(file_issue_request.fetch('items', []).select {|item|
                          !existing_item_refs.include?(item.fetch('record_ref'))
                        })

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

  def self.accept_request_quote(file_issue_request_id, lock_version, request_type)
    updated = db[:file_issue_request]
                .filter(id: file_issue_request_id)
                .filter(lock_version: lock_version)
                .update("#{request_type.downcase}_request_status" => FileIssueRequest::QUOTE_ACCEPTED,
                        lock_version: lock_version + 1,
                        modified_by: Ctx.username,
                        modified_time: java.lang.System.currentTimeMillis,
                        system_mtime: Time.now)

    raise StaleRecordException.new if updated == 0
  end

  def self.cancel_request(file_issue_request_id, lock_version, request_type)
    updated = if request_type
                db[:file_issue_request]
                  .filter(id: file_issue_request_id)
                  .filter(lock_version: lock_version)
                  .update("#{request_type.downcase}_request_status" => FileIssueRequest::CANCELLED_BY_AGENCY,
                          lock_version: lock_version + 1,
                          modified_by: Ctx.username,
                          modified_time: java.lang.System.currentTimeMillis,
                          system_mtime: Time.now)
              else
                db[:file_issue_request]
                  .filter(id: file_issue_request_id)
                  .filter(lock_version: lock_version)
                  .update(digital_request_status: FileIssueRequest::CANCELLED_BY_AGENCY,
                          physical_request_status: FileIssueRequest::CANCELLED_BY_AGENCY,
                          lock_version: lock_version + 1,
                          modified_by: Ctx.username,
                          modified_time: java.lang.System.currentTimeMillis,
                          system_mtime: Time.now)
              end

    raise StaleRecordException.new if updated == 0
  end

  def self.delete_request(file_issue_request_id)
    db[:handle]
      .filter(file_issue_request_id: file_issue_request_id)
      .delete

    db[:file_issue_request_item]
      .filter(file_issue_request_id: file_issue_request_id)
      .delete

    db[:file_issue_request]
      .filter(id: file_issue_request_id)
      .delete
  end

  def self.file_issues(page, page_size, issue_type = nil, status = nil, sort = nil)
    dataset = db[:file_issue]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:file_issue][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:file_issue][:agency_location_id] => current_location.id)
    end

    if issue_type && FileIssue::ISSUE_TYPE_OPTIONS.include?(issue_type)
      dataset = dataset.filter(Sequel[:file_issue][:issue_type] => issue_type)
    end

    if status && FileIssue::STATUS_OPTIONS.include?(status)
      dataset = dataset.filter(Sequel[:file_issue][:status] => status)
    end


    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    sort_by = FILE_ISSUE_SORT_OPTIONS.fetch(sort, FILE_ISSUE_SORT_OPTIONS.fetch('id_desc'))

    dataset = dataset.order(sort_by)

    PagedResults.new(dataset.map{|row| FileIssue.from_row(row)},
                     page,
                     max_page)
  end

  def self.file_issue_dto_for(file_issue_id)
    handle_id = db[:handle][file_issue_id: file_issue_id][:id]

    item_rows_with_tokens = db[:file_issue_item]
                              .left_join(:file_issue_token,
                                         Sequel[:file_issue_item][:file_issue_id] => Sequel[:file_issue_token][:file_issue_id],
                                         Sequel[:file_issue_item][:aspace_record_id] => Sequel[:file_issue_token][:aspace_digital_representation_id])
                              .filter(Sequel[:file_issue_item][:file_issue_id] => file_issue_id)
                              .select_all(:file_issue_item)
                              .select_append(Sequel.as(Sequel[:file_issue_token][:token_key], :file_issue_token))

    FileIssue.from_row(db[:file_issue][id: file_issue_id],
                       handle_id,
                       item_rows_with_tokens)
  end

  def self.get_notifications
    notifications = []

    # find any overdue physical file issues
    db[:file_issue]
      .join(:file_issue_item, Sequel[:file_issue_item][:file_issue_id] => Sequel[:file_issue][:id])
      .filter(Sequel[:file_issue][:agency_id] => Ctx.get.current_location.agency_id)
      .filter(Sequel[:file_issue][:agency_location_id] => Ctx.get.current_location.id)
      .filter(Sequel[:file_issue][:checklist_completed] => 0)
      .filter(Sequel[:file_issue][:issue_type] => FileIssue::ISSUE_TYPE_PHYSICAL)
      .filter(Sequel.~(Sequel[:file_issue_item][:dispatch_date] => nil))
      .filter(Sequel[:file_issue_item][:returned_date] => nil)
      .filter(Sequel.~(Sequel[:file_issue_item][:expiry_date] => nil))
      .filter{ Sequel[:file_issue_item][:expiry_date] < Date.today }
      .select(Sequel[:file_issue][:id],
              Sequel[:file_issue][:issue_type],
              Sequel[:file_issue_item][:expiry_date])
      .distinct
      .map do |row|
      identifier = "FI#{row[:issue_type][0]}#{row[:id]}"
      notifications << Notification.new('file_issue', row[:id], identifier, 'Has overdue items', 'warning', row[:expiry_date].to_time.to_i * 1000)
    end

    # find any recently expired digital file issues
    db[:file_issue]
      .join(:file_issue_item, Sequel[:file_issue_item][:file_issue_id] => Sequel[:file_issue][:id])
      .filter(Sequel[:file_issue][:agency_id] => Ctx.get.current_location.agency_id)
      .filter(Sequel[:file_issue][:agency_location_id] => Ctx.get.current_location.id)
      .filter(Sequel[:file_issue][:checklist_completed] => 0)
      .filter(Sequel[:file_issue][:issue_type] => FileIssue::ISSUE_TYPE_DIGITAL)
      .filter(Sequel.~(Sequel[:file_issue_item][:dispatch_date] => nil))
      .filter(Sequel.~(Sequel[:file_issue_item][:expiry_date] => nil))
      .filter{ Sequel[:file_issue_item][:expiry_date] < Date.today }
      .filter{ Sequel[:file_issue_item][:expiry_date] >= Date.today - Notifications::NOTIFICATION_WINDOW }
      .select(Sequel[:file_issue][:id],
              Sequel[:file_issue][:issue_type],
              Sequel[:file_issue_item][:expiry_date])
      .distinct
      .map do |row|
      identifier = "FI#{row[:issue_type][0]}#{row[:id]}"
      notifications << Notification.new('file_issue', row[:id], identifier, 'Has recently expired items', 'info', row[:expiry_date].to_time.to_i * 1000)
    end

    # find any file issues nearing expiry
    db[:file_issue]
      .join(:file_issue_item, Sequel[:file_issue_item][:file_issue_id] => Sequel[:file_issue][:id])
      .filter(Sequel[:file_issue][:agency_id] => Ctx.get.current_location.agency_id)
      .filter(Sequel[:file_issue][:agency_location_id] => Ctx.get.current_location.id)
      .filter(Sequel[:file_issue][:checklist_completed] => 0)
      .filter(Sequel.~(Sequel[:file_issue_item][:dispatch_date] => nil))
      .filter(Sequel[:file_issue_item][:returned_date] => nil)
      .filter(Sequel.~(Sequel[:file_issue_item][:expiry_date] => nil))
      .filter{ Sequel[:file_issue_item][:expiry_date] >= Date.today }
      .filter{ Sequel[:file_issue_item][:expiry_date] < Date.today + Notifications::NOTIFICATION_WINDOW }
      .select(Sequel[:file_issue][:id],
              Sequel[:file_issue][:issue_type],
              Sequel[:file_issue_item][:expiry_date])
      .distinct
      .map do |row|
      message = if row[:issue_type] == FileIssue::ISSUE_TYPE_DIGITAL
                  'Has items nearing their expiry date'
                else
                  'Has items nearing their return date'
                end

      identifier = "FI#{row[:issue_type][0]}#{row[:id]}"
      notifications << Notification.new('file_issue', row[:id], identifier, message, 'info', row[:expiry_date].to_time.to_i * 1000)
    end

    # find any quotes issued recently
    quote_to_request = {}
    db[:file_issue_request]
      .filter(Sequel[:file_issue_request][:agency_id] => Ctx.get.current_location.agency_id)
      .filter(Sequel[:file_issue_request][:agency_location_id] => Ctx.get.current_location.id)
      .filter(Sequel[:file_issue_request][:digital_request_status] => FileIssueRequest::QUOTE_PROVIDED)
      .select(Sequel[:file_issue_request][:id],
              Sequel[:file_issue_request][:aspace_digital_quote_id])
      .map do |row|
      quote_to_request[row[:aspace_digital_quote_id]] = row[:id]
    end
    db[:file_issue_request]
      .filter(Sequel[:file_issue_request][:agency_id] => Ctx.get.current_location.agency_id)
      .filter(Sequel[:file_issue_request][:agency_location_id] => Ctx.get.current_location.id)
      .filter(Sequel[:file_issue_request][:physical_request_status] => FileIssueRequest::QUOTE_PROVIDED)
      .select(Sequel[:file_issue_request][:id],
              Sequel[:file_issue_request][:aspace_physical_quote_id])
      .map do |row|
      quote_to_request[row[:aspace_physical_quote_id]] = row[:id]
    end

    AspaceDB.open do |aspace_db|
      aspace_db[:service_quote]
        .filter(Sequel[:service_quote][:id] => quote_to_request.keys)
        .filter{ Sequel[:service_quote][:issued_date] > Date.today - Notifications::NOTIFICATION_WINDOW }
        .select(Sequel[:service_quote][:id],
                Sequel[:service_quote][:issued_date])
        .map do |row|
        request_id = quote_to_request.fetch(row[:id])
        notifications << Notification.new('file_issue_request',
                                          request_id,
                                          'F%s' % [request_id],
                                          'Quote issued on %s' % [row[:issued_date].iso8601],
                                          'info',
                                          row[:issued_date].to_time.to_i * 1000)
      end
    end

    [[:file_issue_request, 'Request', 'R%s'],
     [:file_issue, 'File Issue', 'FI%s%s']].each do |record_type, label, identifier_format|
      # created
      dataset = db[record_type]
                  .filter(Sequel[record_type][:agency_id] => Ctx.get.current_location.agency_id)
                  .filter(Sequel[record_type][:agency_location_id] => Ctx.get.current_location.id)
                  .filter(Sequel[record_type][:create_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
                  .select(Sequel[record_type][:id],
                          Sequel[record_type][:create_time],
                          Sequel[record_type][:created_by])

      if record_type == :file_issue
        dataset = dataset.select_append(Sequel[record_type][:issue_type])
      end

      dataset.each do |row|
        identifier = if record_type == :file_issue
                       identifier_format % [row[:issue_type][0], row[:id]]
                     else
                       identifier_format % [row[:id]]
                     end

        notifications << Notification.new(record_type,
                                          row[:id],
                                          identifier,
                                          "%s created by %s" % [label, row[:created_by]],
                                          'info',
                                          row[:create_time])
      end

      # modified
      dataset = db[record_type]
        .filter(Sequel[record_type][:agency_id] => Ctx.get.current_location.agency_id)
        .filter(Sequel[record_type][:agency_location_id] => Ctx.get.current_location.id)
        .filter(Sequel[record_type][:modified_time] > Sequel[record_type][:create_time])
        .filter(Sequel[record_type][:modified_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
        .select(Sequel[record_type][:id],
                Sequel[record_type][:modified_time],
                Sequel[record_type][:modified_by])

      if record_type == :file_issue
        dataset = dataset.select_append(Sequel[record_type][:issue_type])
      end

      dataset.each do |row|
        identifier = if record_type == :file_issue
                       identifier_format % [row[:issue_type][0], row[:id]]
                     else
                       identifier_format % [row[:id]]
                     end

        notifications << Notification.new(record_type,
                                          row[:id],
                                          identifier,
                                          "%s updated by %s" % [label, row[:modified_by]],
                                          'info',
                                          row[:modified_time])
      end
    end

    notifications
  end

  def self.get_file_issue(token)
    row = db[:file_issue_token][:token_key => token]

    if row.nil?
      {status: :missing}
    elsif Time.now.to_i < row[:dispatch_date]
      {status: :not_dispatched}
    elsif Time.now.to_i > row[:expire_date]
      {status: :expired}
    else
      representation_file = AspaceDB.open do |aspace_db|
        aspace_db[:representation_file][:digital_representation_id => row[:aspace_digital_representation_id]]
      end

      mime_type = representation_file[:mime_type]

      begin
        {
          status: :found,
          mime_type: mime_type,
          stream: ByteStorage.get.to_enum(:get_stream, representation_file[:key])
        }
      rescue => e
        $LOG.error("Failure while fetching token #{token}: #{e}")
        {status: :missing}
      end
    end
  end

  # If the user is choosing their items from the search results with no funny
  # business, this should never happen.
  #
  # Just here to catch people monkeying with their requests.
  #
  def self.verify_item_access!(items)
    controlled = Search.select_controlled_records(Ctx.get.permissions, items.map {|item| item.fetch('record_ref')})

    items.each do |item|
      unless controlled.include?(item.fetch('record_ref'))
        Ctx.log_bad_access("verify_item_access!")
        $LOG.error("Requested item '%s' does not appear to be available to current agency" % item.fetch('record_ref'))
        raise StaleRecordException.new
      end
    end
  end

end
