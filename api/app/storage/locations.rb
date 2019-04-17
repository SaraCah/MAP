class Locations < BaseStorage

  def self.page(page, page_size)
    dataset = db[:agency_location]
                .join(:agency, Sequel[:agency][:id] => Sequel[:agency_location][:agency_id])

    unless Ctx.get.permissions.is_admin?
      group_filters = Ctx.get.permissions.admin_groups.map do |group|
        if group.agency_location_id.nil?
          Sequel.&(Sequel[:agency_location][:agency_id] => group.agency_id)
        else
          Sequel.&(Sequel[:agency_location][:id] => group.agency_location_id)
        end
      end

      dataset = dataset.filter(Sequel.|(group_filters))
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

    locations.select{|location| Ctx.get.permissions.location_admin?(location.agency_id, location.id)}
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
end