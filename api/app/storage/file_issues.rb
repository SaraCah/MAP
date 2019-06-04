class FileIssues < BaseStorage

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

    digital_request_status = FileIssueRequest::NONE_REQUESTED
    physical_request_status = FileIssueRequest::NONE_REQUESTED
    if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'DIGITAL'}
      digital_request_status = FileIssueRequest::QUOTE_REQUESTED
    end
    if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'PHYSICAL'}
      physical_request_status = FileIssueRequest::QUOTE_REQUESTED
    end

    file_issue_request_id = db[:file_issue_request].insert(request_type: file_issue_request.fetch('request_type'),
                                                           urgent: file_issue_request.fetch('urgent') ? 1 : 0,
                                                           delivery_location: file_issue_request.fetch('delivery_location'),
                                                           delivery_authorizer: file_issue_request.fetch('delivery_authorizer', nil),
                                                           request_notes: file_issue_request.fetch('request_notes', nil),
                                                           digital_request_status: digital_request_status,
                                                           physical_request_status: physical_request_status,
                                                           agency_id: Ctx.get.current_location.agency_id,
                                                           agency_location_id: Ctx.get.current_location.id,
                                                           created_by: Ctx.username,
                                                           create_time: java.lang.System.currentTimeMillis,
                                                           version: 1,
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

  def self.get_quote(quote_id)
    result = nil

    AspaceDB.open do |aspace_db|
      quote_row = aspace_db[:service_quote][id: quote_id]

      quote = ServiceQuote.new(quote_row[:id], quote_row[:issued_date], 0, []) #FIXME total amount

      aspace_db[:service_quote_line]
        .join(Sequel.as(:enumeration, :charge_quantity_unit_enum), Sequel[:charge_quantity_unit_enum][:name] => 'runcorn_charge_quantity_unit')
        .join(Sequel.as(:enumeration_value, :charge_quantity_unit_enum_value),
              Sequel.&(Sequel[:charge_quantity_unit_enum][:id] => Sequel[:charge_quantity_unit_enum_value][:enumeration_id],
                       Sequel[:charge_quantity_unit_enum_value][:id] => Sequel[:service_quote_line][:charge_quantity_unit_id]))
        .select(
          Sequel.as(Sequel[:service_quote_line][:description], :description),
          Sequel.as(Sequel[:service_quote_line][:quantity], :quantity),
          Sequel.as(Sequel[:service_quote_line][:charge_per_unit_cents], :charge_per_unit_cents),
          Sequel.as(Sequel[:charge_quantity_unit_enum_value][:value], :charge_quantity_unit))
        .filter(service_quote_id: quote_id)
        .order(Sequel[:service_quote_line][:id])
        .map do |line_item_row|
        quote.line_items << ServiceQuoteLineItem.new(line_item_row[:description],
                                                     line_item_row[:quantity],
                                                     line_item_row[:charge_per_unit_cents],
                                                     line_item_row[:charge_quantity_unit],
                                                     line_item_row[:quantity].to_i * line_item_row[:charge_per_unit_cents].to_i) # FIXME pull this from ASpace?
        quote.total_charge_cents += line_item_row[:quantity].to_i * line_item_row[:charge_per_unit_cents].to_i # FIXME pull this from ASpace?
      end

      result = quote
    end

    result
  end

  def self.update_request_from_dto(file_issue_request)
    errors = []

    file_issue_request_id = file_issue_request.fetch('id')

    digital_request_status = FileIssueRequest::NONE_REQUESTED
    physical_request_status = FileIssueRequest::NONE_REQUESTED
    if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'DIGITAL'}
      digital_request_status = FileIssueRequest::QUOTE_REQUESTED
    end
    if file_issue_request.fetch('items').any?{|item| item.fetch('request_type') == 'PHYSICAL'}
      physical_request_status = FileIssueRequest::QUOTE_REQUESTED
    end

    updated = db[:file_issue_request]
                .filter(id: file_issue_request_id)
                .filter(lock_version: file_issue_request.fetch('lock_version'))
                .update(request_type: file_issue_request.fetch('request_type'),
                        urgent: file_issue_request.fetch('urgent') ? 1 : 0,
                        digital_request_status: digital_request_status, # assume any change forces a quote redo
                        physical_request_status: physical_request_status, # assume any change forces a quote redo
                        delivery_location: file_issue_request.fetch('delivery_location'),
                        delivery_authorizer: file_issue_request.fetch('delivery_authorizer', nil),
                        request_notes: file_issue_request.fetch('request_notes', nil),
                        version: file_issue_request.fetch('version') + 1,
                        lock_version: file_issue_request.fetch('lock_version') + 1,
                        system_mtime: Time.now)

    raise StaleRecordException.new if updated == 0

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
                          system_mtime: Time.now)
              else
                db[:file_issue_request]
                  .filter(id: file_issue_request_id)
                  .filter(lock_version: lock_version)
                  .update(digital_request_status: FileIssueRequest::CANCELLED_BY_AGENCY,
                          physical_request_status: FileIssueRequest::CANCELLED_BY_AGENCY,
                          lock_version: lock_version + 1,
                          system_mtime: Time.now)
              end

    raise StaleRecordException.new if updated == 0
  end

  def self.file_issues(page, page_size)
    dataset = db[:file_issue]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:file_issue][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:file_issue][:agency_location_id] => current_location.id)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    dataset = dataset.order(Sequel.desc(Sequel[:file_issue][:create_time]))

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

  def self.chargeable_services
    service_by_id = {}

    AspaceDB.open do |aspace_db|
      aspace_db[:chargeable_service]
        .join(:chargeable_service_item_rlshp, Sequel[:chargeable_service_item_rlshp][:chargeable_service_id] => Sequel[:chargeable_service][:id])
        .join(:chargeable_item, Sequel[:chargeable_item][:id] => Sequel[:chargeable_service_item_rlshp][:chargeable_item_id])
        .join(Sequel.as(:enumeration, :charge_quantity_unit_enum), Sequel[:charge_quantity_unit_enum][:name] => 'runcorn_charge_quantity_unit')
        .join(Sequel.as(:enumeration_value, :charge_quantity_unit_enum_value),
                   Sequel.&(Sequel[:charge_quantity_unit_enum][:id] => Sequel[:charge_quantity_unit_enum_value][:enumeration_id],
                            Sequel[:charge_quantity_unit_enum_value][:id] => Sequel[:chargeable_item][:charge_quantity_unit_id]))
        .filter(Sequel[:chargeable_service][:name] => ['File Issue Physical', 'File Issue Digital'])
        .order(Sequel[:chargeable_service_item_rlshp][:chargeable_service_id], Sequel[:chargeable_service_item_rlshp][:aspace_relationship_position])
        .select(
          Sequel.as(Sequel[:chargeable_service][:id], :chargeable_service_id),
          Sequel.as(Sequel[:chargeable_service][:name], :chargeable_service_name),
          Sequel.as(Sequel[:chargeable_service][:description], :chargeable_service_description),
          Sequel.as(Sequel[:chargeable_item][:id], :chargeable_item_id),
          Sequel.as(Sequel[:chargeable_item][:name], :chargeable_item_name),
          Sequel.as(Sequel[:chargeable_item][:description], :chargeable_item_description),
          Sequel.as(Sequel[:chargeable_item][:price_cents], :chargeable_item_price_cents),
          Sequel.as(Sequel[:charge_quantity_unit_enum_value][:value], :chargeable_item_charge_unit))
        .map do |row|
          service_by_id[row[:chargeable_service_id]] ||= ChargeableService.new(row[:chargeable_service_id],
                                                                               row[:chargeable_service_name],
                                                                               row[:chargeable_service_description], [])
          service_by_id[row[:chargeable_service_id]].items << ChargeableItem.new(row[:chargeable_item_id],
                                                                                 row[:chargeable_item_name],
                                                                                 row[:chargeable_item_description],
                                                                                 row[:chargeable_item_price_cents],
                                                                                 row[:chargeable_item_charge_unit])
        end
    end

    service_by_id.values
  end


  FILE_ISSUE_EXPIRY_WINDOW = 7 # days

  def self.get_notifications
    notifications_per_file_issue = {}
    file_issue_identifiers = {}

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
              Sequel[:file_issue][:issue_type])
      .distinct
      .map do |row|
      identifier = "FI#{row[:issue_type][0]}#{row[:id]}"
      file_issue_identifiers[row[:id]] = identifier
      notifications_per_file_issue[row[:id]] ||= []
      notifications_per_file_issue[row[:id]] << Notification.new("Has overdue items", "warning")
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
      .filter{ Sequel[:file_issue_item][:expiry_date] >= Date.today - FILE_ISSUE_EXPIRY_WINDOW }
      .select(Sequel[:file_issue][:id],
              Sequel[:file_issue][:issue_type])
      .distinct
      .map do |row|
      identifier = "FI#{row[:issue_type][0]}#{row[:id]}"
      file_issue_identifiers[row[:id]] = identifier
      notifications_per_file_issue[row[:id]] ||= []
      notifications_per_file_issue[row[:id]] << Notification.new("Has recently expired items", "info")
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
      .filter{ Sequel[:file_issue_item][:expiry_date] < Date.today + FILE_ISSUE_EXPIRY_WINDOW }
      .select(Sequel[:file_issue][:id],
              Sequel[:file_issue][:issue_type])
      .distinct
      .map do |row|
      identifier = "FI#{row[:issue_type][0]}#{row[:id]}"
      file_issue_identifiers[row[:id]] = identifier
      notifications_per_file_issue[row[:id]] ||= []
      if row[:issue_type] == FileIssue::ISSUE_TYPE_DIGITAL
        notifications_per_file_issue[row[:id]] << Notification.new("Has items nearing their expiry date", "info")
      else
        notifications_per_file_issue[row[:id]] << Notification.new("Has items nearing their return date", "info")
      end
    end

    notifications_per_file_issue.map do |file_issue_id, notifications|
      RecordNotifications.new('file_issue', file_issue_id, file_issue_identifiers.fetch(file_issue_id), notifications)
    end
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

end
