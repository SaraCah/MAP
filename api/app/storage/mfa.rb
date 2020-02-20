class Mfa < BaseStorage

  def self.issue_challenge(user_id)
    user = db[:user][id: user_id]

    raise if !user
    raise if !['totp', 'sms'].include?(user[:mfa_method])

    state = if user[:mfa_method] == 'sms'
              phone_number = db[:mfa_sms][:user_id => user_id][:phone_number]

              if phone_number.nil?
                raise "Phone number not set for user id #{user_id}"
              end

              code = generate_code(6)

              db.after_commit do
                SMS.send(number: phone_number,
                         message: "Your #{AppConfig[:service_name]} code is #{code}",
                         sender: AppConfig[:service_name].gsub(/ /, ''))
              end

              code
            else
              nil
            end

    db[:mfa_challenge].filter(user_id: user_id).delete
    db[:mfa_challenge].insert(user_id: user_id,
                              key: SecureRandom.hex,
                              type: user[:mfa_method],
                              state: state,
                              status: 'pending',
                              expires_after: java.lang.System.currentTimeMillis + (AppConfig[:mfa_expire_seconds] * 1000))
  end


  def self.generate_code(digit_count)
    result = []

    # Unbiased digit
    while result.length < digit_count
      b = SecureRandom.random_bytes(1).ord
      # Discard 250..255 as these would bias towards low digits
      if b < 250
        result << (b % 10)
      end
    end

    result.map(&:to_s).join('')
  end

  def self.check_code(s1, s2)
    return false if s1.length != s2.length

    valid = true

    s1.chars.zip(s2.chars).each do |ch1, ch2|
      valid &= (ch1 == ch2)
    end

    valid
  end


  def self.validate(user_id, verification_code)
    user = db[:user][id: user_id]

    return {validated: false, gone: true} if !user

    now = java.lang.System.currentTimeMillis

    # Expired challenges are no good
    db[:mfa_challenge].filter(:user_id => user_id).where { expires_after < now }.delete

    # Max retries exceeded
    db[:mfa_challenge].filter(:user_id => user_id).where { attempts >= AppConfig[:mfa_max_attempts] }.delete

    # Anything left?
    challenges = db[:mfa_challenge].filter(:user_id => user_id).order(:id).all

    active_challenge = challenges.pop

    # There shouldn't be multiple because we delete old challenges as we create
    # new ones.  But for paranoia...
    db[:mfa_challenge].filter(:id => challenges.map(&:id)).delete

    if !active_challenge
      return {validated: false, gone: true}
    end

    # Show us what you got.
    result = if active_challenge[:type] == 'totp'
               secret = db[:mfa_keys].filter(:user_id => user_id).get(:key)

               if secret
                 totp = ROTP::TOTP.new(secret)
                 totp.verify(verification_code, drift_ahead: 30, drift_behind: 30)
               else
                 false
               end
             elsif user[:mfa_method] == 'sms'
               check_code(active_challenge[:state].to_s, verification_code.to_s.gsub(/[^0-9]/, ''))
             else
               raise "Unknown MFA method"
             end

    if result
      # You win
      db[:mfa_challenge].filter(:id => active_challenge[:id]).delete

      # MFA is now confirmed
      unless user[:mfa_confirmed] == 1
        db[:user].filter(:id => user_id).update(:mfa_confirmed => 1)
      end

      # Now get outta here before I change my mind
      return {validated: true, gone: false}
    else
      db[:mfa_challenge].filter(:id => active_challenge[:id]).update(:attempts => active_challenge[:attempts] + 1)

      if active_challenge[:attempts] + 1 < AppConfig[:mfa_max_attempts]
        return {validated: false, gone: false}
      else
        return {validated: false, gone: true}
      end
    end
  end


  def self.delete_key(user_id)
    db[:mfa_keys].filter(:user_id => user_id).delete
  end


  def self.get_or_create_key(user_id)
    key = db[:mfa_keys].filter(:user_id => user_id).get(:key)

    if !key
      key = ROTP::Base32.random  # returns a 160 bit (32 character) base32 secret. Compatible with Google Authenticator
      save_key(user_id, key)
      key = db[:mfa_keys].filter(:user_id => user_id).get(:key)
    end

    key
  end


  def self.save_key(user_id, key)
    if user_id.nil? || key.nil?
      raise "user_id and key must be set"
    end

    delete_key(user_id)
    db[:mfa_keys].insert(:user_id => user_id,
                         :key => key)
  end


  def self.settings_for_user(user_id)
    totp_secret = Mfa.get_or_create_key(user_id)

    if user = db[:user][id: user_id]
      settings = {
        method: user[:mfa_method],
        confirmed: user[:mfa_confirmed] == 1,
        totp: {
          secret: totp_secret
        },
      }

      if sms = db[:mfa_sms][user_id: user_id]
        settings[:sms] = {
          phone_number: sms[:phone_number]
        }
      end

      settings
    else
      raise "User not found"
    end
  end


  def self.apply_settings_for_user(user_id, settings)
    unless ['none', 'totp', 'sms'].include?(settings['method'])
      raise "Unknown MFA method: #{settings['method']}"
    end

    # We'll require the user to confirm their updated MFA settings in most
    # cases.
    mfa_confirmed = false

    if settings['method'] == 'none'
      # Nothing to confirm here
      mfa_confirmed = true
    end
    if settings['method'] == 'sms'
      # If we already had that number, no need to reconfirm.
      if db[:user][:id => user_id][:mfa_confirmed] == 1 && db[:mfa_sms].filter(user_id: user_id, phone_number: settings.fetch('phone_number')).count > 0
        # We've already confirmed this phone number.
        mfa_confirmed = true
      else
        db[:mfa_sms].filter(user_id: user_id).delete
        db[:mfa_sms].insert(user_id: user_id,
                            phone_number: settings.fetch('phone_number'),
                            create_time: java.lang.System.currentTimeMillis,
                            modified_time: java.lang.System.currentTimeMillis,
                           )
      end
    else
      # Don't store the user's phone number if we won't be using it anymore.
      db[:mfa_sms].filter(user_id: user_id).delete
    end

    db[:user].filter(:id => user_id).update(mfa_method: settings['method'], mfa_confirmed: mfa_confirmed ? 1 : 0)
  end
end
