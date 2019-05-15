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

  def can_manage_locations?(agency_ref)
    is_admin? || agency_roles.any?{|role| role.agency_ref == agency_ref && role.is_agency_admin?}
  end

  def has_role_for_location?(agency_id, agency_location_id)
    is_admin? || is_senior_agency_admin?(agency_id) || agency_roles.any?{|agency_role| agency_role.agency_id == agency_id && agency_role.agency_location_id == agency_location_id}
  end

  def can_create_users?
    is_admin? || agency_roles.any?{|role| role.agency_ref == agency_ref && role.is_agency_admin?}
  end

  def can_edit_user?(user)
    return true if is_admin?

    user.fetch('agency_roles').map do |user_agency_role|
      if agency_roles.any?{|agency_role| agency_role.agency_ref == user_agency_role.fetch('agency_ref') && agency_role.is_agency_admin?}
        return true
      end
    end

    false
  end

  def can_manage_transfers?(agency_id, agency_location_id)
    return true if is_senior_agency_admin?(agency_id)
    return true if is_agency_admin?(agency_id, agency_location_id)

    agency_roles.any?{|agency_role| agency_role.agency_id == agency_id && agency_role.agency_location_id == agency_location_id && agency_role.allow_transfers?}
  end

  def can_manage_file_issues?(agency_id, agency_location_id)
    return true if is_senior_agency_admin?(agency_id)
    return true if is_agency_admin?(agency_id, agency_location_id)

    agency_roles.any?{|agency_role| agency_role.agency_id == agency_id && agency_role.agency_location_id == agency_location_id && agency_role.allow_file_issue?}
  end

  def can_view_conversations?(agency_id, agency_location_id)
    return true if is_admin?
    return true if is_senior_agency_admin?(agency_id)

    agency_roles.any?{|agency_role| agency_role.agency_id == agency_id && agency_role.agency_location_id == agency_location_id}
  end

end