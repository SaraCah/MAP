class Ctx

  def self.open(opts = {})
    raise "Already got a context" if Thread.current[:context]

    Thread.current[:context] = Context.new

    begin
      yield
    ensure
      Thread.current[:context] = nil
    end
  end

  def self.session
    get.session
  end

  def self.username
    get.session[:username]
  end

  def self.client
    get.client
  end

  def self.get
    ctx = Thread.current[:context]
    raise "No context active" unless ctx
    ctx
  end

  def self.permissions
    get.permissions
  end

  class Context
    attr_accessor :session

    def initialize
      @session = nil
    end

    def client
      MAPAPIClient.new(session)
    end

    def permissions
      @permissions ||= client.permissions_for_current_user
    end

    def current_location
      @current_location ||= client.location_for_current_user
    end

    def available_locations
      client.locations_for_current_user
    end
  end

end
