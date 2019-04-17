class Permissions < BaseStorage

  AVAILABLE_PERMISSIONS = [:allow_transfers, :allow_file_issue, :allow_set_raps, :allow_change_raps, :allow_restricted_access]

  def self.agency_roles_for_user(user_id)
    db[:agency_user]
      .join(:agency, Sequel[:agency][:id] => Sequel[:agency_user][:agency_id])
      .join(:agency_location, Sequel[:agency_location][:id] => Sequel[:agency_user][:agency_location_id])
      .filter(Sequel[:agency_user][:user_id] => user_id)
      .select(Sequel.as(Sequel[:agency_user][:id], :agency_user_id),
              Sequel.as(Sequel[:agency_user][:role], :role),
              Sequel.as(Sequel[:agency][:id], :agency_id),
              Sequel.as(Sequel[:agency][:aspace_agency_id], :aspace_agency_id),
              Sequel.as(Sequel[:agency_location][:id], :agency_location_id),
              Sequel.as(Sequel[:agency_location][:name], :agency_location_label),
              Sequel.as(Sequel[:agency_user][:allow_transfers], :allow_transfers),
              Sequel.as(Sequel[:agency_user][:allow_file_issue], :allow_file_issue),
              Sequel.as(Sequel[:agency_user][:allow_set_raps], :allow_set_raps),
              Sequel.as(Sequel[:agency_user][:allow_change_raps], :allow_change_raps),
              Sequel.as(Sequel[:agency_user][:allow_restricted_access], :allow_restricted_access))
      .map do |row|
        AgencyRole.from_row(row)
    end
  end


  def self.add_agency_senior_admin(user_id, agency_id)
    top_level_location = db[:agency_location][:agency_id => agency_id, :top_level_location => 1]

    db[:agency_user].insert(user_id: user_id,
                           agency_id: agency_id, 
                           agency_location_id: top_level_location[:id],
                           role: 'SENIOR_AGENCY_ADMIN',
                           create_time: java.lang.System.currentTimeMillis,
                           modified_time: java.lang.System.currentTimeMillis)
  end


  def self.add_agency_admin(user_id, agency_id, location_id, permissions)
    if location_id.nil?
      location_id = db[:agency_location][:agency_id => agency_id, :top_level_location => 1][:id]
    end

    insert_data = {
      user_id: user_id,
      agency_id: agency_id,
      agency_location_id: location_id,
      role: 'AGENCY_ADMIN',
      allow_transfers: 1, # default permission
      allow_file_issue: 1, # default permission
      create_time: java.lang.System.currentTimeMillis,
      modified_time: java.lang.System.currentTimeMillis
    }

    AVAILABLE_PERMISSIONS.each do |permission|
      insert_data[permission] = 1 if permissions.include?(permission.to_s)
    end

    db[:agency_user].insert(insert_data)
  end


  def self.add_agency_contact(user_id, agency_id, location_id, permissions)
    if location_id.nil?
      location_id = db[:agency_location][:agency_id => agency_id, :top_level_location => 1][:id]
    end

    insert_data = {
      user_id: user_id,
      agency_id: agency_id,
      agency_location_id: location_id,
      role: 'AGENCY_CONTACT',
      create_time: java.lang.System.currentTimeMillis,
      modified_time: java.lang.System.currentTimeMillis
    }

    AVAILABLE_PERMISSIONS.each do |permission|
      insert_data[permission] = 1 if permissions.include?(permission.to_s)
    end

    db[:agency_user].insert(insert_data)
  end


  def self.get_or_create_group(agency_id, location_id, role)
    group = db[:group][:agency_id => agency_id, :agency_location_id => location_id, :role => role]

    if group
      group[:id]
    else
      db[:group].insert(agency_id: agency_id,
                        agency_location_id: location_id,
                        role: role,
                        create_time: java.lang.System.currentTimeMillis,
                        modified_time: java.lang.System.currentTimeMillis)
    end
  end


  def self.available_permissions_for_agency(agency_id)
    AVAILABLE_PERMISSIONS
  end

end