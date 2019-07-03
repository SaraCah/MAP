class Membership
  include DTO

  define_field(:user_id, Integer)
  define_field(:agency_id, Integer)
  define_field(:location_id, Integer)
  define_field(:permissions, [String], default: [])
end

