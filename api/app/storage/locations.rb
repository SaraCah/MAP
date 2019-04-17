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
                    .filter(Sequel[:agency_location][:agency_location_id] => current_location.id)

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
    return if location.has_errors?

    (_, aspace_agency_id) = location.agency_ref.split(':')

    agency_id = Agencies.get_or_create_for_aspace_agency_id(aspace_agency_id)

    # check for uniqueness
    if db[:agency_location][:name => location.name, :agency_id => agency_id].nil?
      db[:agency_location].insert(:name => location.name,
                                  :agency_id => agency_id,
                                  :create_time => java.lang.System.currentTimeMillis,
                                  :modified_time => java.lang.System.currentTimeMillis)
    else
      location.add_error('name', 'already in use')
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
end