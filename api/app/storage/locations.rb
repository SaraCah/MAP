class Locations < BaseStorage

  SORT_OPTIONS = {
    'agency_asc' => [Sequel.asc(Sequel[:agency_location][:agency_id]), Sequel.asc(Sequel[:agency_location][:name])],
    'agency_desc' => [Sequel.desc(Sequel[:agency_location][:agency_id]), Sequel.desc(Sequel[:agency_location][:name])],
    'location_name_asc' => [Sequel.asc(Sequel[:agency_location][:name])],
    'location_name_desc' => [Sequel.desc(Sequel[:agency_location][:name])],
    'created_asc' => [Sequel.asc(Sequel[:agency_location][:create_time])],
    'created_desc' => [Sequel.desc(Sequel[:agency_location][:create_time])],
  }


  def self.all(page, page_size, q = nil, agency_ref = nil, sort = nil)
    if agency_ref
      (_, aspace_agency_id) = agency_ref.split(':')
      agency_id = db[:agency].filter(aspace_agency_id: aspace_agency_id.to_i).select(:id)
      page(page, page_size, agency_id, nil, q, sort)
    else
      page(page, page_size, nil, nil, q, sort)
    end
  end

  def self.for_agency(page, page_size, agency_id, q = nil, sort = nil)
    page(page, page_size, agency_id, nil, q, sort)
  end

  def self.for_agency_location(page, page_size, agency_id, agency_location_id, q = nil, sort = nil)
    page(page, page_size, agency_id, agency_location_id, q, sort)
  end

  def self.page(page, page_size, agency_id = nil, agency_location_id = nil, q = nil, sort = nil)
    dataset = db[:agency_location]
                .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])

    if agency_id
      dataset = dataset.filter(Sequel[:agency_location][:agency_id] => agency_id)
    end

    if agency_location_id
      dataset = dataset.filter(Sequel[:agency_location][:id] => agency_location_id)
    end

    if q
      sanitised = q.downcase.gsub(/[^a-z0-9_\-\. ]/, '')
      dataset = dataset.filter(Sequel.like(Sequel.function(:lower, Sequel[:agency_location][:name]), "%#{sanitised}%"))
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset
                .select_all(:agency_location)
                .select_append(Sequel[:agency][:aspace_agency_id])
                .limit(page_size, page * page_size)

    sort_by = SORT_OPTIONS.fetch(sort, SORT_OPTIONS.fetch('agency_asc'))

    dataset = dataset.order(*sort_by)

    aspace_agencies = {}
    aspace_agency_ids_to_resolve = dataset.map(:aspace_agency_id).uniq

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => aspace_agency_ids_to_resolve)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        aspace_agencies[row[:id]] = Agency.from_row(row)
      end
    end

    PagedResults.new(dataset.map{|row| AgencyLocation.from_row(row, aspace_agencies.fetch(row[:aspace_agency_id]))},
                     page,
                     max_page)
  end

  def self.locations_for_user
    return [] if Ctx.get.permissions.is_admin?

    location_filters = Ctx.get.permissions.agency_roles.map do |agency_role|
      if agency_role.is_senior_agency_admin?
        {Sequel[:agency_location][:agency_id] => agency_role.agency_id}
      else
        Sequel.&(Sequel[:agency_location][:agency_id] => agency_role.agency_id,
                 Sequel[:agency_location][:id] => agency_role.agency_location_id)
      end
    end

    agency_to_locations = {}

    db[:agency_location]
      .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])
      .where(Sequel.|(*location_filters))
      .select(Sequel[:agency_location][:id],
              Sequel[:agency_location][:name],
              Sequel[:agency_location][:agency_id],
              Sequel[:agency][:aspace_agency_id]).each do |row|
      agency_to_locations[row[:aspace_agency_id]] ||= []
      agency_to_locations[row[:aspace_agency_id]] << {
        id: row[:id],
        name: row[:name],
        agency_id: row[:agency_id],
        aspace_agency_id: row[:aspace_agency_id],
      }
    end

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => agency_to_locations.keys)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        agency_to_locations.fetch(row[:id]).map do |location|
          location[:agency_label] = row[:sort_name]
        end
      end
    end

    agency_to_locations.values.flatten(1)
  end

  def self.locations_for_agency(aspace_agency_id)
    agencies = {}

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => aspace_agency_id)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        agencies[row[:id]] = Agency.from_row(row)
      end
    end

    locations = db[:agency_location]
                  .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])
                  .filter(Sequel[:agency][:aspace_agency_id] => aspace_agency_id)
                  .select_all(:agency_location)
                  .select_append(Sequel[:agency][:aspace_agency_id])
                  .map do |row|
      AgencyLocation.from_row(row, agencies.fetch(row[:aspace_agency_id]))
    end

    locations
  end

  def self.create_location_from_dto(location)
    (_, aspace_agency_id) = location.fetch('agency_ref').split(':')

    if !aspace_agency_id
      return [{code: "AGENCY_NOT_FOUND", field: 'agency_ref', field_label: 'agency'}]
    end

    agency_id = Agencies.get_or_create_for_aspace_agency_id(aspace_agency_id)

    # check for uniqueness
    if db[:agency_location][:name => location.fetch('name'), :agency_id => agency_id].nil?
      db[:agency_location].insert(:name => location.fetch('name'),
                                  :delivery_address => location.fetch('delivery_address', nil),
                                  :agency_id => agency_id,
                                  :created_by => Ctx.username,
                                  :create_time => java.lang.System.currentTimeMillis,
                                  :modified_by => Ctx.username,
                                  :modified_time => java.lang.System.currentTimeMillis)

      []
    else
      [{code: "UNIQUE_CONSTRAINT", field: 'name'}]
    end
  end

  def self.update_location_from_dto(location)
    (_, aspace_agency_id) = location.fetch('agency_ref').split(':')

    agency_id = Agencies.get_or_create_for_aspace_agency_id(aspace_agency_id)

    # check for uniqueness
    existing_location = db[:agency_location][name: location.fetch('name'), agency_id: agency_id]
    if existing_location.nil? || existing_location[:id] == Integer(location.fetch('id'))
      updated = db[:agency_location]
                  .filter(id: location.fetch('id'))
                  .filter(lock_version: location.fetch('lock_version'))
                  .update(:name => location.fetch('name'),
                          :delivery_address => location.fetch('delivery_address', nil),
                          :lock_version => location.fetch('lock_version') + 1,
                          :modified_by => Ctx.username,
                          :modified_time => java.lang.System.currentTimeMillis)

      raise StaleRecordException.new if updated == 0

      []
    else
      [{code: "UNIQUE_CONSTRAINT", field: 'name'}]
    end
  end

  def self.default_location
    return nil if Ctx.get.permissions.is_admin?

    first_agency_role = Ctx.get.permissions.agency_roles.first

    agencies = {}
    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => first_agency_role.aspace_agency_id)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        agencies[row[:id]] = Agency.from_row(row)
      end
    end

    db[:agency_location]
      .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])
      .filter(Sequel[:agency][:id] => first_agency_role.agency_id)
      .filter(Sequel[:agency_location][:id] => first_agency_role.agency_location_id)
      .select_all(:agency_location)
      .select_append(Sequel[:agency][:aspace_agency_id])
      .each do |row|

      return AgencyLocation.from_row(row, agencies.fetch(row[:aspace_agency_id]))
    end
  end


  def self.get(agency_id, location_id)
    agencies = {}

    aspace_agency_id = db[:agency][:id => agency_id][:aspace_agency_id]

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => aspace_agency_id)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        agencies[row[:id]] = Agency.from_row(row)
      end
    end

    db[:agency_location]
      .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])
      .filter(Sequel[:agency][:id] => agency_id)
      .filter(Sequel[:agency_location][:id] => location_id)
      .select_all(:agency_location)
      .select_append(Sequel[:agency][:aspace_agency_id])
      .each do |row|

      return AgencyLocation.from_row(row, agencies.fetch(row[:aspace_agency_id]))
    end
  end

  def self.dto_for(location_id)

    location = db[:agency_location][id: location_id]
    aspace_agency_id = db[:agency][id: location[:agency_id]][:aspace_agency_id]

    agency = nil

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => aspace_agency_id)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        agency = Agency.from_row(row)
      end
    end

    raise "Agency not found" if agency.nil?

    AgencyLocationDTO.from_row(location, agency)
  end


  def self.get_notifications(filter_by_current_agency = true)
    notifications = []

    locations_by_aspace_agency = {}

    # any created or updated users
    dataset = db[:agency_location]
                .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])
                .filter(Sequel[:agency_location][:create_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)

    if filter_by_current_agency
      dataset = dataset.filter(Sequel[:agency_location][:agency_id] => Ctx.get.current_location.agency_id)
    end

    dataset.select(Sequel[:agency_location][:id],
                   Sequel[:agency][:aspace_agency_id],
                   Sequel[:agency_location][:name],
                   Sequel[:agency_location][:create_time],
                   Sequel[:agency_location][:created_by])
      .each do |row|
      locations_by_aspace_agency[row[:aspace_agency_id]] ||= []
      locations_by_aspace_agency[row[:aspace_agency_id]] << row.to_hash
    end

    # modified
    dataset = db[:agency_location]
      .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])
      .filter(Sequel[:agency_location][:modified_time] > Sequel[:agency_location][:create_time])
      .filter(Sequel[:agency_location][:modified_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)

    if filter_by_current_agency
      dataset = dataset.filter(Sequel[:agency_location][:agency_id] => Ctx.get.current_location.agency_id)
    end

    dataset.select(Sequel[:agency_location][:id],
                   Sequel[:agency][:aspace_agency_id],
                   Sequel[:agency_location][:name],
                   Sequel[:agency_location][:modified_time],
                   Sequel[:agency_location][:modified_by])
      .each do |row|
      locations_by_aspace_agency[row[:aspace_agency_id]] ||= []
      locations_by_aspace_agency[row[:aspace_agency_id]] << row.to_hash
    end

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => locations_by_aspace_agency.keys)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        locations_by_aspace_agency.fetch(row[:id]).each do |notification_data|
          notification_data[:agency_label] = row[:sort_name]
        end
      end
    end

    locations_by_aspace_agency.values.flatten.each do |notification_data|
      if notification_data.include?(:create_time)
        notifications << Notification.new('location',
                                          notification_data.fetch(:id),
                                          'Location',
                                          '%s created by %s' % [notification_data.fetch(:name), notification_data.fetch(:created_by)],
                                          'info',
                                          notification_data.fetch(:create_time))
      else
        notifications << Notification.new('location',
                                          notification_data.fetch(:id),
                                          'Location',
                                          '%s updated by %s' % [notification_data.fetch(:name), notification_data.fetch(:modified_by)],
                                          'info',
                                          notification_data.fetch(:modified_time))
      end
    end

    notifications
  end
end
