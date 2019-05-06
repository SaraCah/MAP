class Locations < BaseStorage

  def self.page(page, page_size)
    dataset = db[:agency_location]
                .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      if Ctx.get.permissions.is_senior_agency_admin?(current_location.agency_id)
        dataset = dataset
                    .filter(Sequel[:agency_location][:agency_id] => current_location.agency_id)

      elsif Ctx.get.permissions.is_agency_admin?(current_location.agency_id, current_location.id)
        dataset = dataset
                    .filter(Sequel[:agency_location][:agency_id] => current_location.agency_id)
                    .filter(Sequel[:agency_location][:id] => current_location.id)

      else
        raise "Insufficient Privileges"
      end
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset
                .select_all(:agency_location)
                .select_append(Sequel[:agency][:aspace_agency_id])
                .limit(page_size, page * page_size)

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

    agency_id = Agencies.get_or_create_for_aspace_agency_id(aspace_agency_id)

    # check for uniqueness
    if db[:agency_location][:name => location.fetch('name'), :agency_id => agency_id].nil?
      db[:agency_location].insert(:name => location.fetch('name'),
                                  :agency_id => agency_id,
                                  :create_time => java.lang.System.currentTimeMillis,
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
      db[:agency_location]
        .filter(id: location.fetch('id'))
        .update(:name => location.fetch('name'),
                :modified_time => java.lang.System.currentTimeMillis)

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
end