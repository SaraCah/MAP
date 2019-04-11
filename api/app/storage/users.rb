# THINKME: Want an agency ref type?  Type:ID sort of thing

class Users < BaseStorage

  # THINKME: drop permissions here?
  User = Struct.new(:username, :name, :create_time, :permissions) do
    def self.from_row(row)
      User.new(row[:username],
               row[:name],
               row[:create_time],
               {
                'is_admin' => (row[:admin] == 1)
               })
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
      self.agencies[agency_id] = 'MEMBER'
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

  def self.page(page, page_size)
    PagedUsers.new(db[:user].limit(page_size, page * page_size).map {|r| User.from_row(r)},
                   page,
                   (db[:user].count / page_size.to_f).ceil)
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

  def self.permissions_for(username)
    user = db[:user][:username => username]
    {'is_admin' => (user[:admin] == 1)}
  end

  def self.create_from_dto(user)
    if user.valid?
      # check for uniqueness
      if db[:user][:username => user.username].nil?
        user_id = if user.is_admin?
                    self.create_admin_user(user.username, user.name)
                  else
                    self.create_user(user.username, user.name)
                  end

        # user.agencies
        require 'pp';$stderr.puts("\n*** DEBUG #{(Time.now.to_f * 1000).to_i} [users.rb:98 4e5f65]: " + {%Q^user.agencies^ => user.agencies}.pretty_inspect + "\n")

        user.agencies.each do |agency|
          agency_ref = agency.fetch('id')
          is_admin = agency.fetch('role') == 'ADMIN'

          (agency_type, agency_id) = agency_ref.split(':')
          db[:user_agency].insert(user_id: user_id,
                                  agency_type: agency_type,
                                  agency_id: Integer(agency_id),
                                  agency_admin: (is_admin ? 1 : 0),
                                  :create_time => java.lang.System.currentTimeMillis,
                                  :modified_time => java.lang.System.currentTimeMillis)
        end

        DBAuth.set_user_password(user_id, user.password)
      else
        user.add_error('username', 'already in use')
      end
    end
  end

  def self.agencies_for_user(username)
    agency_ids = db[:user]
                  .join(:user_agency, Sequel[:user_agency][:user_id] => Sequel[:user][:id])
                  .filter(Sequel[:user][:username] => username)
                  .map(:agency_id)

    result = {}

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

    agency_permissions = db[:user]
                  .join(:user_agency, Sequel[:user_agency][:user_id] => Sequel[:user][:id])
                  .filter(Sequel[:user][:username] => username)
                  .select(Sequel[:user_agency][:agency_type],
                          Sequel[:user_agency][:agency_id],
                          Sequel[:user_agency][:agency_admin])
                  .each do |row|
      if row[:agency_admin] == 1
        result.add_agency_admin(row[:agency_type] + ":" + row[:agency_id].to_s)
      else
        result.add_agency_member(row[:agency_type] + ":" + row[:agency_id].to_s)
      end
    end

    result
  end

end
