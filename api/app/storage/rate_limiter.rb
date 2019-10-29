# Rate limiting scheme based on a leaky bucket with the passing of time as a counter.
#
# Most excellently described by Pat Wyatt here:
#
#   https://www.codeofhonor.com/blog/using-transaction-rate-limiting-to-improve-service-reliability
#
class RateLimiter < BaseStorage

  RateLimitResult = Struct.new(:rate_limited, :delay_seconds)

  COST_MS = AppConfig[:dbauth_seconds_per_login] * 1000
  MAX_COST_MS = AppConfig[:dbauth_max_login_burst] * COST_MS

  def self.apply_rate_limit(key)
    now = java.lang.System.currentTimeMillis

    if rand < 0.1
      # Expire old entries while we're here
      expire_cutoff = now - MAX_COST_MS
      db[:rate_limit].where { rate_limit_expiry_time < expire_cutoff }.delete
    end

    rate_limit_expiry_time = db[:rate_limit].filter(:key => key).get(:rate_limit_expiry_time) || 0

    # Timeout has expired.  Reset.
    if now > rate_limit_expiry_time
      rate_limit_expiry_time = now
    end

    new_rate_limit_expiry_time = rate_limit_expiry_time + COST_MS

    # Rate limited.  Please wait!
    if (new_rate_limit_expiry_time - now) > MAX_COST_MS
      delay_seconds = ((new_rate_limit_expiry_time - now - MAX_COST_MS) / 1000.0).ceil
      return RateLimitResult.new(true, delay_seconds)
    end

    # OK!
    db[:rate_limit].filter(:key => key).delete
    db[:rate_limit].insert(:key => key, :rate_limit_expiry_time => new_rate_limit_expiry_time)

    RateLimitResult.new(false, 0)
  end

end
