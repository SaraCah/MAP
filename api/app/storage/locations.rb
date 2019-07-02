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
      agency_id = db[:agency].filter(aspace_agency_id: aspace_agency_id.to_i).get(:id)
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

  # FIXME: This is pretty similar to Users#page.  Do we need both still?
  def self.candidates_for_location(permissions, location_id, q = nil, sort = nil, page = 0)
    # Returns a page of users who are candidates for being added to a given location.
    #
    # The logic here is a little complicated, but here we go:
    #
    #  * You can't add a user who is already in this location
    #
    #  * You can't add a senior agency admin of an agency to a location within that agency (no point)
    #
    #  * You can't add a system admin user either (again, no point)
    #
    #  * Otherwise, any user of the current agency is a candidate for being added.
    #
    #  * If the user doing the adding is a senior agency admin, they can add
    #    users from *other* agencies for which they're a senior agency admin.
    #
    #  * If the user doing the adding is a system administrator, they can add
    #    any user that doesn't conflict with the above rules.

    # Permissions check: the current user must either be a sysadmin, or a senior
    # admin for the agency, or an agency admin for the location in question.
    location = self.dto_for(location_id)
    location_agency_id = db[:agency].filter(aspace_agency_id: Integer(location.fetch('agency_ref').split(':')[1])).get(:id)

    role_in_location = permissions.agency_roles.reduce(nil) do |best_role, role|
      if best_role == 'SENIOR_AGENCY_ADMIN'
        # No topping that!
        best_role
      else
        if role.role == 'SENIOR_AGENCY_ADMIN' && "agent_corporate_entity:#{role.aspace_agency_id}" == location.fetch('agency_ref')
          'SENIOR_AGENCY_ADMIN'
        elsif role.role == 'AGENCY_ADMIN' && role.agency_location_id == location_id
          'AGENCY_ADMIN'
        else
          best_role
        end
      end
    end

    unless permissions.is_admin? || role_in_location
      # No permission
      raise "Permission denied"
    end

    dataset = db[:user]
                .left_join(:agency_user, Sequel[:agency_user][:user_id] => Sequel[:user][:id])

    if q
      sanitised = q.downcase.gsub(/[^a-z0-9_\-\. ]/, '_')
      dataset = dataset.filter(Sequel.|(Sequel.like(Sequel.function(:lower, Sequel[:user][:username]), "%#{sanitised}%"),
                                        Sequel.like(Sequel.function(:lower, Sequel[:user][:name]), "%#{sanitised}%")))
    end

    # Users already in the current location shouldn't be included
    existing_location_users = dataset.filter(Sequel[:agency_user][:agency_location_id] => location_id).select(Sequel[:user][:id])
    dataset = dataset.filter(Sequel.~(Sequel[:user][:id] => existing_location_users))

    # Users who are already senior agency admins also should not be included as
    # they're effectively already members of every location.
    senior_agency_admins = dataset.filter(Sequel[:agency_user][:role] => 'SENIOR_AGENCY_ADMIN',
                                          Sequel[:agency_user][:agency_id] => location_agency_id)
                             .select(Sequel[:user][:id])
    dataset = dataset.filter(Sequel.~(Sequel[:user][:id] => senior_agency_admins))

    # Admin users are never eligible
    dataset = dataset.filter(Sequel[:user][:admin] => 0)

    # Inactive users are never eligible
    dataset = dataset.filter(Sequel[:user][:inactive] => 0)

    # If we're a senior agency admin in this agency and others, we can add any
    # user from any of those agencies.
    if role_in_location == 'SENIOR_AGENCY_ADMIN'
      administered_agencies = permissions.agency_roles.map {|role|
        if role.role == 'SENIOR_AGENCY_ADMIN'
          role.agency_id
        else
          nil
        end
      }.compact

      dataset = dataset.filter(Sequel[:agency_user][:agency_id] => administered_agencies)
    elsif role_in_location == 'AGENCY_ADMIN'
      # If we're an agency admin, we can only add from the current agency.
      dataset = dataset.filter(Sequel[:agency_user][:agency_id] => location_agency_id)
    end

    dataset = dataset.select_all(:user).distinct(Sequel[:user][:id])

    page_size = AppConfig[:page_size]
    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    sort_by = Users::SORT_OPTIONS.fetch(sort, Users::SORT_OPTIONS.fetch('username_asc'))
    dataset = dataset.order(sort_by)

    agency_permissions_by_user_id = {}
    aspace_agency_ids_to_resolve = []

    db[:user]
      .left_join(:agency_user, Sequel[:agency_user][:user_id] => Sequel[:user][:id])
      .join(:agency, Sequel[:agency][:id] => Sequel[:agency_user][:agency_id])
      .join(:agency_location, Sequel[:agency_location][:id] => Sequel[:agency_user][:agency_location_id])
      .filter(Sequel[:user][:id] => dataset.select(Sequel[:user][:id]))
      .select(Sequel[:agency_user][:user_id],
              Sequel.as(Sequel[:agency_user][:role], :role),
              Sequel.as(Sequel[:agency_user][:agency_location_id], :agency_location_id),
              Sequel.as(Sequel[:agency_location][:name], :agency_location_label),
              Sequel[:agency][:aspace_agency_id])
      .each do |row|
      agency_ref = "agent_corporate_entity:#{row[:aspace_agency_id]}"
      agency_permissions_by_user_id[row[:user_id]] ||= []
      agency_permissions_by_user_id[row[:user_id]] << [agency_ref, row[:role], row[:agency_location_id], row[:agency_location_label]]
      aspace_agency_ids_to_resolve << row[:aspace_agency_id]
    end

    agencies_by_agency_ref = {}

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => aspace_agency_ids_to_resolve)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        agencies_by_agency_ref['agent_corporate_entity' + ':' + row[:id].to_s] = Agency.from_row(row)
      end
    end

    results = dataset
               .select_all(:user)
               .map do |row|
                 permissions = agency_permissions_by_user_id.fetch(row[:id], [])
                                 .map {|agency_ref, role, location_id, location_label|
                   [
                     agencies_by_agency_ref.fetch(agency_ref),
                     role,
                     location_label
                   ]}

                 User.from_row(row, permissions)
               end

    PagedResults.new(results, page, max_page)
  end

end
