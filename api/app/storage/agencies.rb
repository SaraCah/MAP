class Agencies < BaseStorage

  def self.get_or_create_for_aspace_agency_id(aspace_agency_id)
    agency = db[:agency][aspace_agency_id: aspace_agency_id]

    if agency
      agency[:id]
    else
      db[:agency].insert(aspace_agency_id: aspace_agency_id,
                         create_time: java.lang.System.currentTimeMillis,
                         modified_time: java.lang.System.currentTimeMillis)
    end
  end

  def self.agencies_for_user
    result = {}

    aspace_agency_ids = Ctx.get.permissions.groups.collect(&:aspace_agency_id)

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => aspace_agency_ids)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        result[row[:id]] = Agency.from_row(row)
      end

      aspace_db[:series_system_rlshp]
        .filter(:agent_corporate_entity_id_0 => aspace_agency_ids)
        .filter(:jsonmodel_type => 'series_system_agent_record_ownership_relationship')
        .filter(:end_date => nil)
        .group_and_count(:agent_corporate_entity_id_0).map do |row|
        result[row[:agent_corporate_entity_id_0]].series_count = row[:count]
      end
    end

    result.values
  end
end