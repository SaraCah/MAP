class ReadingRoomRequests < BaseStorage

  REQUEST_SORT_OPTIONS = {
    'id_asc' => Sequel.asc(Sequel[:reading_room_request][:id]),
    'id_desc' => Sequel.desc(Sequel[:reading_room_request][:id]),
    'status_asc' => Sequel.asc(Sequel[:reading_room_request][:status]),
    'status_desc' => Sequel.desc(Sequel[:reading_room_request][:status]),
    'created_asc' => Sequel.asc(Sequel[:reading_room_request][:create_time]),
    'created_desc' => Sequel.desc(Sequel[:reading_room_request][:create_time]),
  }

  def self.requests(page, page_size, status = nil, date_required = nil, sort = nil)
    dataset = db[:reading_room_request]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:reading_room_request][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:reading_room_request][:agency_location_id] => current_location.id)
    end

    if status && ReadingRoomRequest::STATUS_OPTIONS.include?(status)
      dataset = dataset.filter(Sequel[:reading_room_request][:status] => status)
    end

    if date_required
      dataset = dataset.filter(Sequel[:reading_room_request][:date_required] => date_required)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    sort_by = REQUEST_SORT_OPTIONS.fetch(sort, REQUEST_SORT_OPTIONS.fetch('id_desc'))

    dataset = dataset.order(sort_by)

    PagedResults.new(dataset.map{|row| ReadingRoomRequest.from_row(row)},
                     page,
                     max_page)
  end

  def self.create_request_from_dto(reading_room_request, requested_item_ids)
    errors = []

    Search.verify_item_access!(requested_item_ids.map{|id| {'record_ref' => id}})

    uri_for_id = Search.uris_for(requested_item_ids)

    uri_for_id.each do |item_id, item_uri|
      reading_room_request_id = db[:reading_room_request].insert(date_required: Date.parse(reading_room_request.fetch('date_required')).to_time.to_i * 1000,
                                                                 time_required: reading_room_request.fetch('time_required'),
                                                                 status: ReadingRoomRequest::STATUS_PENDING,
                                                                 item_id: item_id,
                                                                 item_uri: item_uri,
                                                                 agency_id: Ctx.get.current_location.agency_id,
                                                                 agency_location_id: Ctx.get.current_location.id,
                                                                 created_by: Ctx.username,
                                                                 create_time: java.lang.System.currentTimeMillis,
                                                                 modified_by: Ctx.username,
                                                                 modified_time: java.lang.System.currentTimeMillis,
                                                                 lock_version: 1,
                                                                 system_mtime: Time.now)

      db[:handle].insert(reading_room_request_id: reading_room_request_id)
    end

    errors
  end

  def self.request_dto_for(reading_room_request_id)
    handle_row = db[:handle][reading_room_request_id: reading_room_request_id]

    return nil unless handle_row

    handle_id = handle_row[:id]
    row = db[:reading_room_request][id: reading_room_request_id]

    ReadingRoomRequest.from_row(row,
                                handle_id)
  end

  def self.get_notifications
    notifications = []

    [[:reading_room_request, 'Reading Room Request', 'RR%s']]
      .each do |record_type, label, identifier_format|
      # created
      dataset = db[record_type]
                  .filter(Sequel[record_type][:agency_id] => Ctx.get.current_location.agency_id)
                  .filter(Sequel[record_type][:agency_location_id] => Ctx.get.current_location.id)
                  .filter(Sequel[record_type][:create_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
                  .select(Sequel[record_type][:id],
                          Sequel[record_type][:create_time],
                          Sequel[record_type][:created_by])

      dataset.each do |row|
        identifier = identifier_format % [row[:id]]

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

      dataset.each do |row|
        identifier = identifier_format % [row[:id]]

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

  def self.cancel_request(reading_room_request_id, lock_version)
    updated = db[:reading_room_request]
                  .filter(id: reading_room_request_id)
                  .filter(lock_version: lock_version)
                  .update(status: ReadingRoomRequest::STATUS_CANCELLED_BY_AGENCY,
                          lock_version: lock_version + 1,
                          modified_by: Ctx.username,
                          modified_time: java.lang.System.currentTimeMillis,
                          system_mtime: Time.now)

    raise StaleRecordException.new if updated == 0
  end
end