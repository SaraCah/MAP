class DB

  def self.connect
    @connection = DBConnection.new(AppConfig[:db_url])
  end

  def self.open(opts = {}, &block)
    @connection.open(opts, &block)
  end

end
