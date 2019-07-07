# THINKME: Want an agency ref type?  Type:ID sort of thing

class Users < BaseStorage

  SORT_OPTIONS = {
    'username_asc' => Sequel.asc(Sequel[:user][:username]),
    'username_desc' => Sequel.desc(Sequel[:user][:username]),
    'name_asc' => Sequel.asc(Sequel[:user][:name]),
    'name_desc' => Sequel.desc(Sequel[:user][:name]),
    'created_asc' => Sequel.asc(Sequel[:user][:create_time]),
    'created_desc' => Sequel.desc(Sequel[:user][:create_time]),
  }

  def self.all(page, page_size, q = nil, agency_ref = nil, role = nil, sort = nil)
    if agency_ref
      (_, aspace_agency_id) = agency_ref.split(':')
      agency_id = db[:agency].filter(aspace_agency_id: aspace_agency_id.to_i).get(:id)
      page(page, page_size, agency_id, nil, q, role, sort)
    else
      page(page, page_size, nil, nil, q, role, sort)
    end
  end

  def self.for_agency(page, page_size, agency_id, q = nil, role = nil, sort = nil)
    page(page, page_size, agency_id, nil, q, role, sort)
  end

  def self.for_agency_location(page, page_size, agency_id, agency_location_id, q = nil, role = nil, sort = nil)
    page(page, page_size, agency_id, agency_location_id, q, role,sort)
  end

  def self.page(page, page_size, agency_id = nil, agency_location_id = nil, q = nil, role = nil, sort = nil)
    dataset = db[:user]
                .left_join(:agency_user, Sequel[:agency_user][:user_id] => Sequel[:user][:id])

    if agency_id
      dataset = dataset.filter(Sequel[:agency_user][:agency_id] => agency_id)
    end

    if agency_location_id
      dataset = dataset.filter(Sequel[:agency_user][:agency_location_id] => agency_location_id)
    end

    if q
      sanitised = q.downcase.gsub(/[^a-z0-9_\-\. ]/, '_')
      dataset = dataset.filter(Sequel.|(Sequel.like(Sequel.function(:lower, Sequel[:user][:username]), "%#{sanitised}%"), Sequel.like(Sequel.function(:lower, Sequel[:user][:name]), "%#{sanitised}%")))
    end

    if role
      dataset = dataset.filter(Sequel[:agency_user][:role] => role)
    end

    dataset = dataset.select_all(:user).distinct(Sequel[:user][:id])

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    sort_by = SORT_OPTIONS.fetch(sort, SORT_OPTIONS.fetch('username_asc'));
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
                 permissions = agency_permissions_by_user_id.fetch(row[:id], []).map {|agency_ref, role, location_id, location_label| [ agencies_by_agency_ref.fetch(agency_ref), role, location_label ]}
                 User.from_row(row, permissions)
               end

    PagedResults.new(results, page, max_page)
  end

  def self.user_exists?(username)
    !!db[:user][:username => username]
  end

  # Returns ID of new user
  def self.create_user(username, name, email)
    db[:user].insert(:username => username,
                     :name => name,
                     :email => email,
                     :admin => 0,
                     :created_by => Ctx.username,
                     :create_time => java.lang.System.currentTimeMillis,
                     :modified_by => Ctx.username,
                     :modified_time => java.lang.System.currentTimeMillis)
  end

  def self.create_admin_user(username, name, email)
    db[:user].insert(:username => username,
                     :name => name,
                     :email => email,
                     :admin => 1,
                     :created_by => Ctx.username,
                     :create_time => java.lang.System.currentTimeMillis,
                     :modified_by => Ctx.username,
                     :modified_time => java.lang.System.currentTimeMillis)
  end

  def self.id_for_username(username)
    db[:user][:username => username][:id]
  end

  def self.name_for(username)
    db[:user][:username => username][:name]
  end

  def self.update_from_dto(user)

      data_for_update = {
        name: user.fetch('name'),
        lock_version: user.fetch('lock_version') + 1,
        inactive: user.fetch('is_inactive') ? 1 : 0,
        modified_by: Ctx.username,
        modified_time: java.lang.System.currentTimeMillis
      }

      if Ctx.get.permissions.can_manage_agencies?
        data_for_update[:email] = user.fetch('email')
      end

      updated = db[:user]
                  .filter(id: user.fetch('id'))
                  .filter(lock_version: user.fetch('lock_version'))
                  .update(data_for_update)

      raise StaleRecordException.new if updated == 0

      unless user.fetch('password').empty?
        DBAuth.set_user_password(user.fetch('id'), user.fetch('password'))
      end

      []
  end

  def self.create_from_dto(user)
    # check for uniqueness
    if db[:user][:username => user.fetch('username')].nil?
      user_id = if Ctx.get.permissions.is_admin? && user.fetch('is_admin')
                  self.create_admin_user(user.fetch('username'), user.fetch('name'), user.fetch('email'))
                else
                  self.create_user(user.fetch('username'), user.fetch('username'), user.fetch('email'))
                end

      unless user.fetch('is_admin')
        user.fetch('agency_roles', []).each do |agency_role|
          agency_ref = agency_role.fetch('agency_ref')
          role = agency_role.fetch('role')
          location_id = agency_role.fetch('agency_location_id', nil)
          permissions = agency_role.fetch('permissions')
          position = agency_role.fetch('position')

          (_, aspace_agency_id) = agency_ref.split(':')
          agency_id = Agencies.get_or_create_for_aspace_agency_id(aspace_agency_id)

          if location_id.nil? || location_id == ''
            location_id = Locations.locations_for_agency(aspace_agency_id).first.id
          end

          if role == 'SENIOR_AGENCY_ADMIN'
            Permissions.add_agency_senior_admin(user_id, agency_id, position)
          elsif role == 'AGENCY_ADMIN'
            Permissions.add_agency_admin(user_id, agency_id, location_id, position, permissions)
          elsif role == 'AGENCY_CONTACT'
            Permissions.add_agency_contact(user_id, agency_id, location_id, position, permissions)
          end
        end
      end

      DBAuth.set_user_password(user_id, user.fetch('password'))

      []
    else
      [{code: "UNIQUE_CONSTRAINT", field: 'username'}]
    end
  end

  def self.permissions_for_user(username)
    result = AgencyPermissions.new

    user = db[:user][:username => username]

    # FIXME: we call this is_admin everywhere else...
    result.is_admin = (user[:admin] == 1)

    Permissions.agency_roles_for_user(user[:id]).each do |agency_role|
      result.add_agency_role(agency_role)
    end

    result
  end

  def self.dto_for(username)
    user = db[:user][:username => username]

    return nil unless user

    UserDTO.from_row(
      user,
      Permissions.agency_roles_for_user(user[:id], with_labels: true))
  end

  def self.validate_roles(dto)
    errors = []

    # Rule: You can create or update a user if their roles are a subset of yours.

    if Ctx.get.permissions.is_admin?
    # No dramas
    else
      dto.fetch('agency_roles').each do |agency_role|
        (_, aspace_agency_id) = agency_role.fetch('agency_ref').split(':')
        agency_id = db[:agency].filter(aspace_agency_id: Integer(aspace_agency_id)).get(:id)

        # Only system admins can create senior agency admins
        if agency_role.fetch('role') == 'SENIOR_AGENCY_ADMIN'
          errors << {code: "INSUFFICIENT_PRIVILEGES", field: 'agency_roles'}
        elsif Ctx.get.permissions.is_senior_agency_admin?(agency_id)
        # We're a senior admin for this agency, so that's fine.
        elsif Ctx.get.permissions.is_agency_admin?(agency_id,
                                                   agency_role.fetch('agency_location_id'))
        # We're an admin for this location; also fine.
        else
          errors << {code: "INSUFFICIENT_PRIVILEGES", field: 'agency_roles'}
        end
      end
    end

    errors
  end


  def self.get_notifications
    notifications = []

    # any created or updated users
    db[:user]
      .filter(Sequel[:user][:create_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
      .select(Sequel[:user][:username],
              Sequel[:user][:create_time],
              Sequel[:user][:created_by])
      .each do |row|
      notifications << Notification.new(:user,
                                        row[:username],
                                        "User",
                                        "User created by %s" % [row[:created_by]],
                                        'info',
                                        row[:create_time])
    end

    # modified
    db[:user]
      .filter(Sequel[:user][:modified_time] > Sequel[:user][:create_time])
      .filter(Sequel[:user][:modified_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
      .select(Sequel[:user][:username],
              Sequel[:user][:modified_time],
              Sequel[:user][:modified_by])
      .each do |row|
      notifications << Notification.new(:user,
                                        row[:username],
                                        "User",
                                        "%s updated by %s" % [row[:username], row[:modified_by]],
                                        'info',
                                        row[:modified_time])
    end

    notifications
  end


  def self.get_system_admins
    db[:user]
      .filter(admin: 1)
      .map do |row|
        UserDTO.from_row(row)
      end
  end
end
