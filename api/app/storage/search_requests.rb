class SearchRequests < BaseStorage

  SEARCH_REQUEST_SORT_OPTIONS = {
    'id_asc' => Sequel.asc(Sequel[:search_request][:id]),
    'id_desc' => Sequel.desc(Sequel[:search_request][:id]),
    'status_asc' => Sequel.asc(Sequel[:search_request][:status]),
    'status_desc' => Sequel.desc(Sequel[:search_request][:status]),
    'created_asc' => Sequel.asc(Sequel[:search_request][:create_time]),
    'created_desc' => Sequel.desc(Sequel[:search_request][:create_time]),
  }

  def self.search_requests(page, page_size, status = nil, sort = nil)
    dataset = db[:search_request]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:search_request][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:search_request][:agency_location_id] => current_location.id)
    end

    if status && SearchRequest::STATUS_OPTIONS.include?(status)
      dataset = dataset.filter(Sequel[:search_request][:status] => status)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    sort_by = SEARCH_REQUEST_SORT_OPTIONS.fetch(sort, SEARCH_REQUEST_SORT_OPTIONS.fetch('id_desc'))

    dataset = dataset.order(sort_by)

    PagedResults.new(dataset.map{|row| SearchRequest.from_row(row)},
                     page,
                     max_page)
  end

  def self.create_from_dto(search_request)
    errors = []

    status, lodged_by = if search_request.fetch('draft')
                          [SearchRequest::INACTIVE, nil] 
                        else
                          username = Users.name_for(Ctx.username)
                          position = Ctx.get.user_position

                          [SearchRequest::SUBMITTED, "%s (%s)" % [username, position]]
                        end

    search_request_id = db[:search_request].insert(details: search_request.fetch('details'),
                                                   date_details: search_request.fetch('date_details', nil),
                                                   purpose: search_request.fetch('purpose', nil),
                                                   draft: search_request.fetch('draft') ? 1 : 0,
                                                   status: status,
                                                   lodged_by: lodged_by,
                                                   agency_id: Ctx.get.current_location.agency_id,
                                                   agency_location_id: Ctx.get.current_location.id,
                                                   created_by: Ctx.username,
                                                   create_time: java.lang.System.currentTimeMillis,
                                                   modified_by: Ctx.username,
                                                   modified_time: java.lang.System.currentTimeMillis,
                                                   version: 1,
                                                   system_mtime: Time.now)

    db[:handle].insert(search_request_id: search_request_id)

    errors
  end

  def self.dto_for(search_request_id)
    handle_row = db[:handle][search_request_id: search_request_id]

    return nil unless handle_row

    handle_id = handle_row[:id]
    row = db[:search_request][id: search_request_id]

    SearchRequest.from_row(row,
                           handle_id,
                           db[:search_request_file].filter(search_request_id: search_request_id))
  end

  def self.update_from_dto(search_request)
    errors = []

    search_request_id = search_request.fetch('id')

    existing_search_request = db[:search_request][id: search_request_id]

    status = existing_search_request[:status]

    is_draft = search_request.fetch('draft')
    lodged_by = existing_search_request[:lodged_by]

    if existing_search_request[:draft] == 1
      if !is_draft
        status = SearchRequest::SUBMITTED

        username = Users.name_for(Ctx.username)
        position = Ctx.get.user_position
        lodged_by = "%s (%s)" % [username, position]
      end
    else
      is_draft = false
    end

    update_data = {
      details: search_request.fetch('details'),
      date_details: search_request.fetch('date_details', nil),
      purpose: search_request.fetch('purpose', nil),
      draft: is_draft ? 1 : 0,
      status: status,
      lodged_by: lodged_by,
      lock_version: search_request.fetch('lock_version') + 1,
      modified_by: Ctx.username,
      modified_time: java.lang.System.currentTimeMillis,
      system_mtime: Time.now
    }

    updated = db[:search_request]
                .filter(id: search_request_id)
                .filter(lock_version: search_request.fetch('lock_version'))
                .update(update_data)

    raise StaleRecordException.new if updated == 0

    errors
  end

  def self.cancel(search_request_id, lock_version)
    errors = []

    updated = db[:search_request]
                .filter(id: search_request_id)
                .filter(lock_version: lock_version)
                .update(status: SearchRequest::CANCELLED_BY_AGENCY,
                        lock_version: lock_version + 1,
                        modified_by: Ctx.username,
                        modified_time: java.lang.System.currentTimeMillis,
                        system_mtime: Time.now)

    raise StaleRecordException.new if updated == 0

    errors
  end

  def self.get_notifications
    notifications = []

    # created
    db[:search_request]
      .filter(Sequel[:search_request][:agency_id] => Ctx.get.current_location.agency_id)
      .filter(Sequel[:search_request][:agency_location_id] => Ctx.get.current_location.id)
      .filter(Sequel[:search_request][:create_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
      .select(Sequel[:search_request][:id],
              Sequel[:search_request][:create_time],
              Sequel[:search_request][:created_by])
      .each do |row|
      notifications << Notification.new('search_request',
                                        row[:id],
                                        "SR%s" % [row[:id]],
                                        "%s created by %s" % ['Search Request', row[:created_by]],
                                        'info',
                                        row[:create_time])
    end

    # modified
    db[:search_request]
      .filter(Sequel[:search_request][:agency_id] => Ctx.get.current_location.agency_id)
      .filter(Sequel[:search_request][:agency_location_id] => Ctx.get.current_location.id)
      .filter(Sequel[:search_request][:modified_time] > Sequel[:search_request][:create_time])
      .filter(Sequel[:search_request][:modified_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
      .select(Sequel[:search_request][:id],
              Sequel[:search_request][:modified_time],
              Sequel[:search_request][:modified_by])
      .each do |row|
      notifications << Notification.new('search_request',
                                        row[:id],
                                        "SR%s" % [row[:id]],
                                        "%s updated by %s" % ['Search Request', row[:modified_by]],
                                        'info',
                                        row[:modified_time])
    end

    notifications
  end
end