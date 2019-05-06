class UserDTO
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:username, String)
  define_field(:name, String)
  define_field(:password, String, required: false, validator: proc {|s, user| user.new? && s.empty? ? "Password can't be blank" : nil})
  define_field(:is_admin, Boolean, default: false)
  define_field(:is_inactive, Boolean, default: false)
  define_field(:agency_roles, [AgencyRoleDTO], default: [], validator: proc {|arr, user| !user.fetch('is_admin', false) && arr.empty? ? "Agency Role can't be blank" : nil})
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)

  def self.from_row(row, agency_roles = [])
    new(id: row[:id],
        username: row[:username],
        name: row[:name],
        is_admin: (row[:admin] == 1),
        is_inactive: (row[:inactive] == 1),
        agency_roles: agency_roles.map{|agency_permission| AgencyRoleDTO.from_agency_role(agency_permission)},
        created_by: row[:created_by],
        create_time: row[:create_time])
  end
end