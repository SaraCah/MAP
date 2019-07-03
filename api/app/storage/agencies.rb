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

  def self.for_edit(agency_ref)
    aspace_agency_id = Integer(agency_ref.split(':')[1])
    agency = aspace_agencies([aspace_agency_id]).values.first

    return nil unless agency

    result = AgencyForEdit.new(agency_ref: agency_ref, locations: [])
    result[:label] = agency.label

    # Locations
    locations_by_id = {}

    db[:agency]
      .join(:agency_location, Sequel[:agency_location][:agency_id] => Sequel[:agency][:id])
      .filter(Sequel[:agency][:aspace_agency_id] => aspace_agency_id)
      .select_all(:agency_location).each do |row|
      locations_by_id[row[:id]] = AgencyForEdit::LocationWithMembers.new(:location => AgencyLocationDTO.from_row(row, agency),
                                                                         :members => [])
    end

    can_edit_user_by_username = {}

    # Users and their roles
    db[:agency]
      .join(:agency_user, Sequel[:agency][:id] => Sequel[:agency_user][:agency_id])
      .join(:user, Sequel[:user][:id] => Sequel[:agency_user][:user_id])
      .filter(Sequel[:agency][:aspace_agency_id] => aspace_agency_id)
      .select(Sequel.as(Sequel[:user][:id], :user_id),
              Sequel[:user][:username],
              Sequel[:user][:name],
              Sequel[:agency_user][:agency_location_id],
              Sequel[:agency_user][:role],
              Sequel[:agency_user][:allow_transfers],
              Sequel[:agency_user][:allow_file_issue],
              Sequel[:agency_user][:allow_set_raps],
              Sequel[:agency_user][:allow_change_raps],
              Sequel[:agency_user][:allow_restricted_access],)
      .each do |row|

      member = AgencyForEdit::MemberDTO.new(
        :user_id => row[:user_id],
        :username => row[:username],
        :name => row[:name],
        :role => row[:role],
        :permissions => Permissions::AVAILABLE_PERMISSIONS.select {|perm| row[perm] == 1}.map(&:to_s),
      )

      can_edit_user_by_username[row[:username]] = false

      locations_by_id.fetch(row[:agency_location_id]).fetch(:members) << member
    end

    can_edit_user_by_username.keys.each do |username|
      if Ctx.get.permissions.is_admin? || username === Ctx.username
        can_edit_user_by_username[username] = true
        next
      end

      can_edit_user_by_username[username] = Users.permissions_for_user(username).agency_roles.all?{|agency_role|
        Ctx.get.permissions.can_edit_agency_role?(agency_role.agency_ref, agency_role.agency_location_id, agency_role.role)
      }
    end

    result[:locations] = locations_by_id.values

    result.fetch(:locations).sort! {|a, b|
      if a.fetch(:location).fetch(:is_top_level, false)
        -1
      elsif b.fetch(:location).fetch(:is_top_level, false)
        1
      else
        a.fetch(:location).fetch(:name) <=> b.fetch(:location).fetch(:name)
      end
    }

    result.fetch(:locations).each do |location|
      location.fetch(:members).each do |member|
        member['editable'] = can_edit_user_by_username.fetch(member.fetch('username'))
      end
      location.fetch(:members).sort_by! {|member| member.fetch(:username).downcase}
    end

    result
  end
end
