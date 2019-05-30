class AspaceDB

  def self.connect
    @pool = DBPool.new(AppConfig[:aspace_db_url]).connect
    @connected = true
  end

  def self.open
    raise "Not connected" unless @connected

    result = nil
    @pool.transaction(rollback: :always) do |db|
      result = yield db
    end

    return result
  end
end
