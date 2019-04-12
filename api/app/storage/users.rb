# THINKME: Want an agency ref type?  Type:ID sort of thing

class Users < BaseStorage

  User = Struct.new(:username, :name, :is_admin, :create_time, :agency_permissions) do
    def self.from_row(row, agency_permissions)
      User.new(row[:username],
               row[:name],
               (row[:admin] == 1),
               row[:create_time],
               agency_permissions)
    end

    def to_json(*args)
      to_h.to_json
    end
  end

  Agency = Struct.new(:id, :label, :series_count) do
    def self.from_row(row)
      Agency.new("agent_corporate_entity:#{row[:id]}",
                 row[:sort_name], 0)
    end

    def to_json(*args)
      to_h.to_json
    end
  end

  Permissions = Struct.new(:is_admin, :agencies) do
    def initialize
      self.is_admin = false
      self.agencies = {}
    end

    def add_agency_admin(agency_id)
      self.agencies[agency_id] = 'ADMIN'
    end

    def add_agency_member(agency_id)
      self.agencies[agency_id] ||= 'MEMBER'
    end

    def to_json(*args)
      to_h.to_json
    end
  end

  PagedUsers = Struct.new(:users, :current_page, :max_page) do
    def to_json(*args)
      to_h.to_json
    end
  end

  def self.page(agency_refs, page, page_size)
    dataset = db[:user]

    unless agency_refs == 'ANY'
      agency_user_ids = db[:user_agency].filter(Sequel[:user_agency][:agency_ref] => agency_refs).select(Sequel[:user_agency][:user_id])
      dataset = dataset.filter(Sequel[:user][:id] => agency_user_ids)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    agency_permissions_by_user_id = {}
    agency_ids = []

    permission_dataset = dataset.from_self(:alias => :user).join(:user_agency, Sequel[:user_agency][:user_id] => Sequel[:user][:id])
    unless agency_refs == 'ANY'
      permission_dataset = permission_dataset.filter(Sequel[:user_agency][:agency_ref] => agency_refs)
    end

    permission_dataset
      .select(Sequel[:user_agency][:user_id],
              Sequel[:user_agency][:agency_ref],
              Sequel[:user_agency][:agency_admin],
              Sequel[:user_agency][:agency_id])
      .each do |row|
      agency_permissions_by_user_id[row[:user_id]] ||= []
      agency_permissions_by_user_id[row[:user_id]] << [row[:agency_ref], (row[:agency_admin] == 1) ? 'ADMIN' : 'MEMBER']
      agency_ids << row[:agency_id]
    end

    agencies_by_agency_ref = {}

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => agency_ids)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        # FIXME ref business
        agencies_by_agency_ref['agent_corporate_entity' + ':' + row[:id].to_s] = Agency.from_row(row)
      end
    end


    PagedUsers.new(dataset.map {|r| User.from_row(r, agency_permissions_by_user_id.fetch(r[:id], []).map {|agency_ref, role| [ agencies_by_agency_ref.fetch(agency_ref), role ]})},
                   page,
                   max_page)
  end

  def self.user_exists?(username)
    !!db[:user][:username => username]
  end

  # Returns ID of new user
  def self.create_user(username, name)
    db[:user].insert(:username => username,
                     :name => name,
                     :admin => 0,
                     :create_time => java.lang.System.currentTimeMillis,
                     :modified_time => java.lang.System.currentTimeMillis)
  end

  def self.create_admin_user(username, name)
    db[:user].insert(:username => username,
                     :name => name,
                     :admin => 1,
                     :create_time => java.lang.System.currentTimeMillis,
                     :modified_time => java.lang.System.currentTimeMillis)
  end

  def self.id_for_username(username)
    db[:user][:username => username][:id]
  end

  # FIXME replaced with permissions_for_user
  def self.permissions_for(username)
    user = db[:user][:username => username]
    {'is_admin' => (user[:admin] == 1)}
  end

  def self.create_from_dto(user)
    return if user.has_errors?

    # check for uniqueness
    if db[:user][:username => user.username].nil?
      user_id = if user.is_admin?
                  self.create_admin_user(user.username, user.name)
                else
                  self.create_user(user.username, user.name)
                end

      user.agencies.each do |agency|
        agency_ref = agency.fetch('id')
        is_admin = agency.fetch('role') == 'ADMIN'

        (agency_type, agency_id) = agency_ref.split(':')
        db[:user_agency].insert(user_id: user_id,
                                agency_type: agency_type,
                                agency_id: Integer(agency_id),
                                agency_ref: agency_ref,
                                agency_admin: (is_admin ? 1 : 0),
                                :create_time => java.lang.System.currentTimeMillis,
                                :modified_time => java.lang.System.currentTimeMillis)
      end

      DBAuth.set_user_password(user_id, user.password)
    else
      user.add_error('username', 'already in use')
    end
  end

  def self.agencies_for_user(username)
    permissions = Ctx.get.permissions
    result = {}

    # FIXME: blegh
    agency_ids = permissions.agencies.keys.map {|s| Integer(s.split(':').last)}

    AspaceDB.open do |aspace_db|
      aspace_db[:agent_corporate_entity]
        .join(:name_corporate_entity, Sequel[:agent_corporate_entity][:id] => Sequel[:name_corporate_entity][:agent_corporate_entity_id])
        .filter(Sequel[:name_corporate_entity][:authorized] => 1)
        .filter(Sequel[:agent_corporate_entity][:id] => agency_ids)
        .select(Sequel[:agent_corporate_entity][:id],
                Sequel[:name_corporate_entity][:sort_name]).each do |row|
        result[row[:id]] = Agency.from_row(row)
      end

      aspace_db[:series_system_rlshp]
        .filter(:agent_corporate_entity_id_0 => agency_ids)
        .filter(:jsonmodel_type => 'series_system_agent_record_ownership_relationship')
        .filter(:end_date => nil)
        .group_and_count(:agent_corporate_entity_id_0).map do |row|
        result[row[:agent_corporate_entity_id_0]].series_count = row[:count]
      end
    end

    result.values
  end

  def self.permissions_for_user(username)
    result = Permissions.new

    user = db[:user][:username => username]

    # FIXME: we call this is_admin everywhere else...
    result.is_admin = (user[:admin] == 1)

    member_agency_ids = db[:user]
                          .join(:user_agency, Sequel[:user_agency][:user_id] => Sequel[:user][:id])
                          .filter(Sequel[:user][:username] => username)
                          .map(:agency_id)

    descendant_agencies = {}
    AspaceDB.open do |aspace_db|
      aspace_db[:agency_descendant]
        .filter(:agent_corporate_entity_id => member_agency_ids)
        .select(Sequel[:agency_descendant][:agent_corporate_entity_id],
                Sequel[:agency_descendant][:descendant_id])
        .each do |row|
        descendant_agencies[row[:agent_corporate_entity_id]] ||= []
        descendant_agencies[row[:agent_corporate_entity_id]] << row[:descendant_id]
      end
    end

    agency_permissions = db[:user]
                  .join(:user_agency, Sequel[:user_agency][:user_id] => Sequel[:user][:id])
                  .filter(Sequel[:user][:username] => username)
                  .select(Sequel[:user_agency][:agency_type],
                          Sequel[:user_agency][:agency_id],
                          Sequel[:user_agency][:agency_admin])
                  .each do |row|
      if row[:agency_admin] == 1
        result.add_agency_admin(row[:agency_type] + ":" + row[:agency_id].to_s)
        descendant_agencies.fetch(row[:agency_id], []).each do |descendant_id|
          result.add_agency_admin(row[:agency_type] + ":" + descendant_id.to_s)
        end
      else
        result.add_agency_member(row[:agency_type] + ":" + row[:agency_id].to_s)
        descendant_agencies.fetch(row[:agency_id], []).each do |descendant_id|
          result.add_agency_member(row[:agency_type] + ":" + descendant_id.to_s)
        end
      end
    end

    result
  end

end
