class Permissions < BaseStorage

  AVAILABLE_PERMISSIONS = [:allow_transfers, :allow_file_issue, :allow_set_raps, :allow_change_raps, :allow_restricted_access]

  def self.agency_roles_for_user(user_id, with_labels: false)
    agency_roles = db[:agency_user]
                    .join(:agency, Sequel[:agency][:id] => Sequel[:agency_user][:agency_id])
                    .join(:agency_location, Sequel[:agency_location][:id] => Sequel[:agency_user][:agency_location_id])
                    .filter(Sequel[:agency_user][:user_id] => user_id)
                    .select(Sequel.as(Sequel[:agency_user][:id], :agency_user_id),
                            Sequel.as(Sequel[:agency_user][:role], :role),
                            Sequel.as(Sequel[:agency_user][:position], :position),
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
                      agency_role = AgencyRole.from_row(row)
                      agency_role.agency_location_label = row[:agency_location_label] if with_labels
                      agency_role
                    end

    if with_labels
      aspace_agencies = Agencies.aspace_agencies(agency_roles.map(&:aspace_agency_id))
      agency_roles.each do |agency_role|
        agency_role.agency_label = aspace_agencies.fetch(agency_role.aspace_agency_id).label
      end
    end

    agency_roles
  end


  def self.clear_roles(user_id)
    if Ctx.get.permissions.is_admin?
      db[:agency_user].filter(:user_id => user_id).delete
    else
      db[:agency_user]
        .filter(:user_id => user_id)
        .filter(:agency_location_id => Ctx.get.current_location.id)
        .delete
    end
  end


  def self.add_agency_senior_admin(user_id, agency_id, position)
    top_level_location = db[:agency_location][:agency_id => agency_id, :top_level_location => 1]

    db[:agency_user].insert(user_id: user_id,
                           agency_id: agency_id, 
                           agency_location_id: top_level_location[:id],
                           role: 'SENIOR_AGENCY_ADMIN',
                           position: position,
                           create_time: java.lang.System.currentTimeMillis,
                           modified_time: java.lang.System.currentTimeMillis)
  end


  def self.add_agency_admin(user_id, agency_id, location_id, position, permissions)
    if location_id.nil?
      location_id = db[:agency_location][:agency_id => agency_id, :top_level_location => 1][:id]
    end

    insert_data = {
      user_id: user_id,
      agency_id: agency_id,
      agency_location_id: location_id,
      role: 'AGENCY_ADMIN',
      position: position,
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


  def self.add_agency_contact(user_id, agency_id, location_id, position, permissions)
    if location_id.nil?
      location_id = db[:agency_location][:agency_id => agency_id, :top_level_location => 1][:id]
    end

    insert_data = {
      user_id: user_id,
      agency_id: agency_id,
      agency_location_id: location_id,
      role: 'AGENCY_CONTACT',
      position: position,
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


  def self.permissions_for_agency_user(user_id, agency_id, location_id)
    current_role = db[:agency_user][:user_id => user_id, :agency_id => agency_id, :agency_location_id => location_id]
    AVAILABLE_PERMISSIONS.select{|permission| current_role[permission] == 1}.map(&:to_s)
  end

  def self.assign_to_location(user_id, location_id, role, position = 'Not yet provided')
    errors = []

    agency_id = db[:agency_location].filter(:id => location_id).get(:agency_id)

    if Ctx.get.permissions.is_admin? || Ctx.get.permissions.is_agency_admin?(agency_id, location_id)
      if role == 'AGENCY_ADMIN'
        self.add_agency_admin(user_id, agency_id, location_id, position, [])
      elsif role == 'AGENCY_CONTACT'
        self.add_agency_contact(user_id, agency_id, location_id, position, [])
      elsif role == 'SENIOR_AGENCY_ADMIN' && Ctx.get.permissions.is_admin?
        self.add_agency_senior_admin(user_id, agency_id, position)
      else
        errors << ["Invalid role given"]
      end
    else
      errors << ["Permission denied"]
    end

    errors
  end

  def self.get_location_membership(user_id, location_id)
    agency_id = db[:agency_location].filter(:id => location_id).get(:agency_id)

    if Ctx.get.permissions.is_admin? || Ctx.get.permissions.is_agency_admin?(agency_id, location_id)
      row = db[:agency_user][:user_id => user_id, :agency_location_id => location_id]

      return nil unless row

      permissions = AVAILABLE_PERMISSIONS.select {|permission| row[permission] == 1}

      Membership.new(user_id: user_id,
                     agency_id: agency_id,
                     location_id: location_id,
                     permissions: permissions)
    else
      nil
    end
  end

  def self.set_membership_permissions(user_id, location_id, permissions, role, position)
    # Permissions being set must be a subset of the permissions available to the
    # user doing the setting.  If `user_id` has other permissions outside of
    # that set, we want to leave them untouched.
    agency_id = db[:agency_location].filter(:id => location_id).get(:agency_id)

    available_permissions = if Ctx.get.permissions.is_senior_agency_admin?(agency_id) || Ctx.get.permissions.is_admin?
                              AVAILABLE_PERMISSIONS.map(&:to_s)
                            else
                              self.permissions_for_agency_user(Users.id_for_username(Ctx.username),
                                                               agency_id,
                                                               location_id)
                            end

    if Ctx.get.permissions.is_admin? || Ctx.get.permissions.is_agency_admin?(agency_id, location_id)

      if role == 'SENIOR_AGENCY_ADMIN' && !Ctx.get.permissions.is_admin?
        # Only system admins can create senior agency admins. This isn't allowed.
        role = nil
      elsif ['SENIOR_AGENCY_ADMIN', 'AGENCY_CONTACT', 'AGENCY_ADMIN'].include?(role)
        # OK
      else
        # Unknown role
        role = nil
      end
      

      row = db[:agency_user][:user_id => user_id, :agency_location_id => location_id]

      return nil unless row

      updates = available_permissions.map {|permission|
        [permission.intern, permissions.include?(permission) ? 1 : 0]
      }.to_h

      if role
        updates[:role] = role
      end

      updates[:position] = position

      db[:agency_user]
        .filter(:user_id => user_id, :agency_location_id => location_id)
        .update(updates)
    else
      nil
    end
  end

end
