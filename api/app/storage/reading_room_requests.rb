class ReadingRoomRequests < BaseStorage

  REQUEST_SORT_OPTIONS = {
    'id_asc' => Sequel.asc(Sequel[:reading_room_request][:id]),
    'id_desc' => Sequel.desc(Sequel[:reading_room_request][:id]),
    'status_asc' => Sequel.asc(Sequel[:reading_room_request][:status]),
    'status_desc' => Sequel.desc(Sequel[:reading_room_request][:status]),
    'created_asc' => Sequel.asc(Sequel[:reading_room_request][:create_time]),
    'created_desc' => Sequel.desc(Sequel[:reading_room_request][:create_time]),
  }

  def self.requests(page, page_size, status = nil, sort = nil)
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
      reading_room_request_id = db[:reading_room_request].insert(date_required: reading_room_request.fetch('date_required'),
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
end