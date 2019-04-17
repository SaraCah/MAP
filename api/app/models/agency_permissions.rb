AgencyPermissions = Struct.new(:is_admin, :agency_roles) do
  def initialize
    self.is_admin = false
    self.agency_roles = []
  end

  def is_admin?
    self.is_admin == true
  end

  def add_agency_role(agency_role)
    self.agency_roles << agency_role
  end

  def is_senior_agency_admin?(agency_id)
    self.agency_roles.any?{|agency_role| agency_role.agency_id == agency_id && agency_role.is_senior_agency_admin?}
  end

  def is_agency_admin?(agency_id, location_id)
    is_senior_agency_admin?(agency_id) || self.agency_roles.any?{|agency_role| agency_role.agency_id == agency_id && agency_role.agency_location_id == location_id &&  agency_role.is_agency_admin?}
  end

  def to_json(*args)
    to_h.to_json
  end

end