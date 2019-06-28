class Agencies < BaseStorage

  def self.get_or_create_for_aspace_agency_id(aspace_agency_id)
    agency = db[:agency][aspace_agency_id: aspace_agency_id]

    if agency
      agency[:id]
    else
      agency_id = db[:agency].insert(aspace_agency_id: aspace_agency_id,
                                     created_by: Ctx.username,
                                     create_time: java.lang.System.currentTimeMillis,
                                     modified_by: Ctx.username,
                                     modified_time: java.lang.System.currentTimeMillis)

      db[:agency_location].insert(agency_id: agency_id,
                                  name: 'Agency Top Level Location',
                                  top_level_location: 1,
                                  created_by: Ctx.username,
                                  create_time: java.lang.System.currentTimeMillis,
                                  modified_by: Ctx.username,
                                  modified_time: java.lang.System.currentTimeMillis)

      agency_id
    end
  end

  def self.get_summary(agency_id)
    result = {}

    aspace_agency_id = db[:agency][:id => agency_id][:aspace_agency_id]

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => aspace_agency_id)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        result[row[:id]] = Agency.from_row(row)
      end

      aspace_db[:series_system_rlshp]
        .filter(:agent_corporate_entity_id_0 => aspace_agency_id)
        .filter(:jsonmodel_type => 'series_system_agent_record_ownership_relationship')
        .filter(:end_date => nil)
        .group_and_count(:agent_corporate_entity_id_0).map do |row|
        result[row[:agent_corporate_entity_id_0]].series_count = row[:count]
      end
    end

    result.values.first
  end

  def self.aspace_agencies(aspace_agency_ids)
    result = {}

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => aspace_agency_ids)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        result[row[:id]] = Agency.from_row(row)
      end
    end

    result
  end

  def self.for_permissions(permissions, q: nil, page: 0, page_size: AppConfig[:page_size])
    AspaceDB.open do |aspace_db|
      dataset = aspace_db[:agent_corporate_entity]
                  .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
                  .filter(Sequel[:name_corporate_entity][:authorized] => 1)
                  .order(Sequel[:name_corporate_entity][:sort_name])
                  .select(Sequel[:agent_corporate_entity][:id],
                          Sequel[:name_corporate_entity][:sort_name])

      if q
        sanitised = q.downcase.gsub(/[^a-z0-9_\-\. ]/, '')
        dataset = dataset.filter(Sequel.like(Sequel.function(:lower, Sequel[:name_corporate_entity][:sort_name]), "%#{sanitised}%"))
      end

      unless permissions.is_admin?
        dataset = dataset.filter(Sequel[:agent_corporate_entity][:id] => permissions.agency_roles.map(&:aspace_agency_id))
      end

      max_page = (dataset.count / page_size.to_f).ceil

      PagedResults.new(dataset
                         .limit(page_size, page * page_size)
                         .map {|row| Agency.from_row(row)},
                       page,
                       max_page)
    end
  end
end
