class Users < BaseStorage

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

  def self.page(page, page_size)
    db[:user].limit(page_size, page * page_size).map do |row|
      User.from_row(row)
    end
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

        user.agencies.each do |agency_ref|
          (agency_type, agency_id) = agency_ref.split(':')
          db[:user_agency].insert(user_id: user_id,
                                  agency_type: agency_type,
                                  agency_id: Integer(agency_id),
                                  :create_time => java.lang.System.currentTimeMillis,
                                  :modified_time => java.lang.System.currentTimeMillis)
        end

        DBAuth.set_user_password(user_id, user.password)
      else
        user.add_error('username', 'already in use')
      end
    end
  end

end
