require_relative 'agency_location_dto'

class AgencyForEdit
  include DTO

  class MemberDTO
    include DTO

    define_field(:username, String)
    define_field(:name, String)
    define_field(:role, String)
    define_field(:permissions, [String])
    define_field(:is_user_editable, Boolean, default: false)
  end

  class LocationWithMembers
    include DTO

    define_field(:location, AgencyLocationDTO)
    define_field(:members, [MemberDTO])
  end


  define_field(:agency_ref, String)
  define_field(:label, String)
  define_field(:locations, [LocationWithMembers])
end
