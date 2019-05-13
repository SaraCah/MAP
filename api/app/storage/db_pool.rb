class DBPool

  attr_reader :pool

  def initialize(db_url, pool_size = AppConfig[:db_max_connections], opts = {})
    @db_url = db_url
    @pool_size = pool_size
    @opts = opts
    @pool = nil
  end

  def connect
    return if @pool

    begin
      @pool = Sequel.connect(@db_url,
                             max_connections: @pool_size,
                             test: true,
                             loggers: AppConfig[:enable_db_logging] ? $LOG : [])

      self
    rescue
      $LOG.info("DB connection failed: #{$!}")
      raise
    end
  end

  def transaction(*args)
    @pool.transaction(*args) do
      yield(@pool)
    end
  end
end
