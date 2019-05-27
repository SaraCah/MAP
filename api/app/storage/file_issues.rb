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
    row = db[:file_issue_request][id: file_issue_request_id]
    file_issue_request = FileIssueRequest.from_row(row,
                                                   handle_id,
                                                   db[:file_issue_request_item].filter(file_issue_request_id: file_issue_request_id))
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

  def self.accept_request_quote(file_issue_request_id, request_type)
    db[:file_issue_request]
      .filter(id: file_issue_request_id)
      .update("#{request_type.downcase}_request_status" => FileIssueRequest::QUOTE_ACCEPTED,
              system_mtime: Time.now)
  end

  def self.cancel_request(file_issue_request_id, request_type)
    if request_type
      db[:file_issue_request]
        .filter(id: file_issue_request_id)
        .update("#{request_type.downcase}_request_status" => FileIssueRequest::CANCELLED_BY_AGENCY,
                system_mtime: Time.now)
    else
      db[:file_issue_request]
        .filter(id: file_issue_request_id)
        .update(digital_request_status: FileIssueRequest::CANCELLED_BY_AGENCY,
                physical_request_status: FileIssueRequest::CANCELLED_BY_AGENCY,
                system_mtime: Time.now)
    end
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
    FileIssue.from_row(db[:file_issue][id: file_issue_id],
                      handle_id,
                      db[:file_issue_item].filter(file_issue_id: file_issue_id))
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
end
