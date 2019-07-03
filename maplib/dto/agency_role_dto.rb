class AgencyRoleDTO
  include DTO

  define_field(:agency_ref, String)
  define_field(:agency_label, String, required: false)
  define_field(:role, String)
  define_field(:agency_location_id, Integer)
  define_field(:agency_location_label, String, required: false)
  define_field(:permissions, [String], default: [])
  define_field(:location_options, [AgencyLocationOption], default: [])

  def self.from_agency_role(agency_role)
    new(agency_ref: agency_role.agency_ref,
        agency_label: agency_role.agency_label,
        role: agency_role.role,
        agency_location_id: agency_role.agency_location_id,
        agency_location_label: agency_role.agency_location_label,
        permissions: agency_role.permissions)
  end
end