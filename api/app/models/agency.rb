Agency = Struct.new(:id, :label, :series_count, :controlled_records) do
  def self.from_row(row)
    Agency.new("agent_corporate_entity:#{row[:id]}",
               row[:sort_name], 0)
  end

  def to_json(*args)
    to_h.to_json
  end
end
