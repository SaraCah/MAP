class Users < BaseStorage

  def self.user_exists?(username)
    !!db[:user][:username => username]
  end

  # Returns ID of new user
  def self.create_user(username, name)
    db[:user].insert(:username => username,
                     :name => name,
                     :create_time => java.lang.System.currentTimeMillis,
                     :modified_time => java.lang.System.currentTimeMillis)
  end



end
