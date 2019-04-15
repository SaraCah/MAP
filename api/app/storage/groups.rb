class Groups < BaseStorage

  def self.group_user_dataset
    db[:group_user]
      .join(:group, Sequel[:group][:id] => Sequel[:group_user][:group_id])
      .join(:agency, Sequel[:agency][:id] => Sequel[:group][:agency_id])
      .left_outer_join(:agency_location, Sequel[:agency_location][:id] => Sequel[:group][:agency_location_id])
  end


  def self.groups_for_user(user_id)
    group_user_dataset
      .filter(Sequel[:group_user][:user_id] => user_id)
      .select(Sequel.as(Sequel[:group][:id], :group_id),
              Sequel.as(Sequel[:agency][:id], :agency_id),
              Sequel.as(Sequel[:agency][:aspace_agency_id], :aspace_agency_id),
              Sequel.as(Sequel[:group][:role], :role),
              Sequel.as(Sequel[:agency_location][:id], :agency_location_id),
              Sequel.as(Sequel[:agency_location][:name], :agency_location_label))
      .map do |row|
      GroupPermission.from_row(row)
    end
  end


  def self.add_user_to_agency(user_id, agency_id, role)
    group_id = get_or_create_group(agency_id, nil, role)

    db[:group_user].insert(user_id: user_id,
                           group_id: group_id,
                           create_time: java.lang.System.currentTimeMillis,
                           modified_time: java.lang.System.currentTimeMillis)
  end


  def self.add_user_to_agency_location(user_id, agency_id, location_id, role)
    group_id = get_or_create_group(agency_id, location_id, role)

    db[:group_user].insert(user_id: user_id,
                           group_id: group_id,
                           create_time: java.lang.System.currentTimeMillis,
                           modified_time: java.lang.System.currentTimeMillis)
  end


  def self.get_or_create_group(agency_id, location_id, role)
    group = db[:group][:agency_id => agency_id, :agency_location_id => location_id, :role => role]

    if group
      group[:id]
    else
      db[:group].insert(role: role,
                        agency_id: agency_id,
                        agency_location_id: location_id,
                        create_time: java.lang.System.currentTimeMillis,
                        modified_time: java.lang.System.currentTimeMillis)
    end
  end


  def self.add_user_to_group(user_id, group_id)
    db[:group_user].insert(user_id: user_id,
                           group_id: group_id,
                           create_time: java.lang.System.currentTimeMillis,
                           modified_time: java.lang.System.currentTimeMillis)
  end

end