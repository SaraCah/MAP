AgencyLocation = Struct.new(:id, :name, :agency_id, :create_time, :agency) do
  def self.from_row(row, agency = nil)
    AgencyLocation.new(row[:id],
                       row[:name],
                       row[:agency_id],
                       row[:create_time],
                       agency)
  end

  def to_json(*args)
    to_h.to_json
  end
end