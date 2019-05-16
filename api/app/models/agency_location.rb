AgencyLocation = Struct.new(:id, :name, :agency_id, :create_time, :agency) do
  def self.from_row(row, agency = nil)
    self.new(row[:id],
             row[:name],
             row[:agency_id],
             row[:create_time],
             agency ? Utils.hash_keys_to_strings(agency.to_h) : nil)
  end

  def self.from_hash(hash)
    self.new(hash.fetch('id'),
             hash.fetch('name'),
             hash.fetch('agency_id'),
             hash.fetch('create_time'),
             hash.fetch('agency'))
  end

  def agency_ref
    agency.fetch('id')
  end

  def to_json(*args)
    to_h.to_json
  end
end
