class DBAuth < BaseStorage

  def self.set_user_password(user_id, password)
    db[:dbauth].insert(:user_id => user_id,
                       :pwhash => BCrypt::Password.create(password))
  end

  def self.authenticate(username, password)
    hash = db[:user]
             .join(:dbauth, Sequel[:dbauth][:user_id] => Sequel[:user][:id])
             .filter(Sequel[:user][:username] => username)
             .get(Sequel[:dbauth][:pwhash])

    if hash
       BCrypt::Password.new(hash) == password
    else
      false
    end
  end
end