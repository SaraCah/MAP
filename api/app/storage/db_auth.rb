class DBAuth < BaseStorage

  def self.set_user_password(user_id, password)
    db[:dbauth].filter(:user_id => user_id).delete
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

  def self.issue_password_reset(username)
    user = db[:user][:username => username]

    unless user && user[:email]
      sleep rand * 2.0
      return
    end

    token = SecureRandom.hex(64)

    db[:dbauth].filter(:user_id => user[:id])
      .update(:recovery_token => token,
              :recovery_token_issue_time => java.lang.System.currentTimeMillis)

    PasswordResetNotification.new(token, user).send!
  end

  def self.valid_reset_token?(token)
    password_reset_ttl_ms = AppConfig[:password_reset_ttl_seconds] * 1000

    # Make sure they have at least a few minutes left or they're probably not
    # going to make it anyway.
    grace_period = 120000
    now = java.lang.System.currentTimeMillis

    earliest_allowed = now - password_reset_ttl_ms + grace_period

    row = db[:dbauth]
            .filter(:recovery_token => token)
            .where { recovery_token_issue_time > earliest_allowed }
            .first

    if row
      row[:user_id]
    else
      nil
    end
  end

end
