class AspaceDB

  def self.connect
    @connection = DBConnection.new(AppConfig[:aspace_db_url])
  end

  def self.open(opts = {}, &block)
    @connection.open(opts.merge(rollback: :always), &block)
  end

end
