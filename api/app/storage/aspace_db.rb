class AspaceDB

  def self.connect
    @pool = DBPool.new(AppConfig[:aspace_db_url]).connect
    @connected = true
  end

  def self.open
    raise "Not connected" unless @connected

    @pool.transaction(rollback: :always) do |db|
      return yield db
    end
  end
end
