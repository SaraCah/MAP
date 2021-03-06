require_relative 'agency_location_dto'

class AgencyForEdit
  include DTO

  class MemberDTO
    include DTO

    define_field(:username, String)
    define_field(:name, String)
    define_field(:email, String)
    define_field(:role, String)
    define_field(:permissions, [String])
    define_field(:is_user_editable, Boolean, default: false)
    define_field(:is_membership_editable, Boolean, default: false)
    define_field(:is_inactive, Boolean, default: false)
  end

  class LocationWithMembers
    include DTO

    define_field(:location, AgencyLocationDTO)
    define_field(:members, [MemberDTO])
    define_field(:is_location_editable, Boolean, default: false)
  end


  define_field(:agency_ref, String)
  define_field(:label, String)
  define_field(:locations, [LocationWithMembers])
  define_field(:is_agency_editable, Boolean, default: false)
end
