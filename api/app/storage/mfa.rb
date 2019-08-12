class Mfa < BaseStorage

  def self.has_key?(user_id)
    secret = db[:mfa_keys].filter(:user_id => user_id).get(:key)
    !!secret
  end

  def self.key_verified(user_id, authcode)
    require 'rotp'
    secret = db[:mfa_keys].filter(:user_id => user_id).get(:key)
    return nil unless secret
    totp = ROTP::TOTP.new(secret)
    totp.verify(authcode)
  end

  def self.get_key(user_id)
    db[:mfa_keys].filter(:user_id => user_id).get(:key)
  end

end
