class Ctx

  def self.open(opts = {})
    DB.open(opts) do |db|
      raise "Already got a context" if Thread.current[:context]

      Thread.current[:context] = Context.new(db)

      begin
        yield
      ensure
        Thread.current[:context] = nil
      end
    end
  end

  def self.db
    get.db
  end

  def self.username
    get.session.username
  end

  def self.get
    ctx = Thread.current[:context]
    raise "No context active" unless ctx
    ctx
  end

  class Context
    attr_reader :db
    attr_accessor :session

    def initialize(db)
      @db = db
      @session = nil
    end
  end

end
