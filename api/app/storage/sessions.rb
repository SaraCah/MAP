class Sessions < BaseStorage

  class SessionNotFoundError < StandardError
  end

  class Session
    attr_reader :id, :username, :create_time, :data

    def initialize(id, username, create_time, data)
      @id = id
      @username = username
      @create_time = create_time
      @data = data
    end

    def [](key)
      self.data[key.to_s]
    end

    def []=(key, value)
      self.data[key.to_s] = value
    end
  end


  # Returns session ID
  def self.create_session(username)
    session_id = SecureRandom.hex
    db[:session].insert(:session_id => session_id,
                        :username => username,
                        :create_time => java.lang.System.currentTimeMillis,
                        :last_used_time => java.lang.System.currentTimeMillis,
                        :session_data => "{}")

    session_id
  end


  def self.get_session(session_id)
    row = db[:session][:session_id => session_id]

    if row
      Session.new(row[:session_id], row[:username], row[:create_time], JSON.parse(row[:session_data]))
    else
      raise SessionNotFoundError.new
    end
  end

  def self.save_session(session)
    delete_session(session.id)

    db[:session].insert(:session_id => session.id,
                        :username => session.username,
                        :create_time => session.create_time,
                        :last_used_time => java.lang.System.currentTimeMillis,
                        :session_data => JSON.dump(session.data))
  end

  def self.delete_session(session_id)
    db[:session].filter(:session_id => session_id).delete
  end

end
