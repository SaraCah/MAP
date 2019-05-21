ChargeableItem = Struct.new(:id, :name, :description, :price_cents, :charge_quantity_unit) do
  def to_json(*args)
    to_h.to_json
  end
end