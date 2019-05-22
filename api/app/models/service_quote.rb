ServiceQuote = Struct.new(:id, :issued_date, :total_charge_cents, :line_items) do
  def to_json(*args)
    to_h.to_json
  end
end

ServiceQuoteLineItem = Struct.new(:description, :quantity, :charge_per_unit_cents, :charge_quantity_unit, :charge_cents) do
  def to_json(*args)
    to_h.to_json
  end
end