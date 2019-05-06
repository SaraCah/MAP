class AgencyLocationDTO
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:name, String)
  define_field(:agency_ref, String) # FIXME
  define_field(:agency_label, String, required: false)
end