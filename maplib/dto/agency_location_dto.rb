class AgencyLocationDTO
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:name, String)
  define_field(:agency_ref, String) # FIXME
  define_field(:agency_label, String, required: false)
  define_field(:delivery_address, String, required: false)
  define_field(:is_top_level, Boolean, required: false)

  def self.from_row(row, agency)
    new(id: row[:id],
        name: row[:name],
        agency_ref: agency.id,
        agency_label: agency.label,
        delivery_address: row[:delivery_address],
        is_top_level: row[:top_level_location] == 1,
        lock_version: row[:lock_version])
  end
end
