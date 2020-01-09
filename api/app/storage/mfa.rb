class Mfa < BaseStorage

  def self.has_key?(user_id)
    secret = db[:mfa_keys].filter(:user_id => user_id).get(:key)
    !!secret
  end

  def self.key_verified(user_id, authcode)
    secret = db[:mfa_keys].filter(:user_id => user_id).get(:key)
    return nil unless secret
    totp = ROTP::TOTP.new(secret)
    totp.verify(authcode, drift_ahead: 30, drift_behind: 30)
  end

  def self.get_key(user_id)
    db[:mfa_keys].filter(:user_id => user_id).get(:key)
  end

  def self.save_key(user_id, key)
    p key
    if !key.nil? && !key.empty?
      db[:mfa_keys].filter(:user_id => user_id).delete
      db[:mfa_keys].insert(:user_id => user_id,
                                  :key => key)
    end

    []
  end

end
