class BaseStorage

  def self.db
    Ctx.db or raise "No DB set"
  end

end
