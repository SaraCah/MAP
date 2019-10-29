class DBAuth < BaseStorage

  def self.set_user_password(user_id, password)
    db[:dbauth].filter(:user_id => user_id).delete
    db[:dbauth].insert(:user_id => user_id,
                       :pwhash => BCrypt::Password.create(password))
  end

  class AuthenticationResult
    def initialize(success, delay_seconds)
      @success = success
      @delay_seconds = delay_seconds
    end

    def success?
      @success
    end

    def delay_seconds
      @delay_seconds
    end
  end


  # Rate limiting scheme based on a leaky bucket with the passing of time as a counter.
  #
  # Most excellently described by Pat Wyatt here:
  #
  #   https://www.codeofhonor.com/blog/using-transaction-rate-limiting-to-improve-service-reliability
  #
  def self.apply_rate_limit(rate_limit_expiry_time, now)
    cost_ms = AppConfig[:dbauth_seconds_per_login] * 1000
    max_cost_ms = AppConfig[:dbauth_max_login_burst] * cost_ms

    # Timeout has expired.  Reset.
    if now > rate_limit_expiry_time
      rate_limit_expiry_time = now
    end

    new_rate_limit_expiry_time = rate_limit_expiry_time + cost_ms

    # Rate limited.  Please wait!
    if (new_rate_limit_expiry_time - now) > max_cost_ms
      delay_seconds = ((new_rate_limit_expiry_time - now - max_cost_ms) / 1000.0).ceil
      return [true, rate_limit_expiry_time, delay_seconds]
    end

    # OK!
    [false, new_rate_limit_expiry_time, 0]
  end

  def self.authenticate(username, password)
    user_auth = db[:user]
                  .join(:dbauth, Sequel[:dbauth][:user_id] => Sequel[:user][:id])
                  .filter(Sequel[:user][:username] => username)
                  .filter(Sequel[:user][:inactive] => 0)
                  .select(Sequel[:dbauth][:id],
                          Sequel[:dbauth][:pwhash],
                          Sequel[:dbauth][:rate_limit_expiry_time])
                  .first

    return false if !user_auth

    now = java.lang.System.currentTimeMillis
    rate_limited, new_expiry_time, delay_seconds = apply_rate_limit(user_auth[:rate_limit_expiry_time], now)

    if rate_limited
      return AuthenticationResult.new(false, delay_seconds)
    end

    update_count = db[:dbauth].filter(id: user_auth[:id],
                                      rate_limit_expiry_time: user_auth[:rate_limit_expiry_time])
                     .update(rate_limit_expiry_time: new_expiry_time)

    if update_count == 0
      # Concurrent login attempts?  Get outta here.
      return AuthenticationResult.new(false, 0)
    end


    if user_auth
      AuthenticationResult.new(BCrypt::Password.new(user_auth[:pwhash]) == password,
                               0)
    else
      AuthenticationResult.new(false, 0)
    end
  end
end
