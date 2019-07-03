ChargeableService = Struct.new(:id, :name, :description, :last_revised_statement, :items) do
  def to_json(*args)
    to_h.to_json
  end
end
