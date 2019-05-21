ChargeableService = Struct.new(:id, :name, :description, :items) do
  def to_json(*args)
    to_h.to_json
  end
end