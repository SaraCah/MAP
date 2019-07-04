AgencyPermissions = Struct.new(:is_admin, :agency_roles) do
  def initialize
    self.is_admin = false
    self.agency_roles = []
  end

  def is_admin?
    self.is_admin == true
  end

  def position_for(agency_ref, location_id)
    agency_role = self.agency_roles.detect{|agency_role| agency_role.agency_ref == agency_ref && agency_role.agency_location_id == location_id}
    agency_role.position
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

  def can_manage_agencies?
    is_admin? || agency_roles.any?{|role| role.is_agency_admin?}
  end

  def can_manage_locations?(agency_ref)
    is_admin? || agency_roles.any?{|role| role.agency_ref == agency_ref && role.is_agency_admin?}
  end

  def has_role_for_location?(agency_id, agency_location_id)
    is_admin? || is_senior_agency_admin?(agency_id) || agency_roles.any?{|agency_role| agency_role.agency_id == agency_id && agency_role.agency_location_id == agency_location_id}
  end

  def can_create_users?(agency_ref = nil)
    is_admin? || agency_roles.any?{|role| role.agency_ref == agency_ref && role.is_agency_admin?}
  end

  def can_edit_user?(user)
    return true if is_admin?
    return true if user.fetch('username', nil) === Ctx.username
    return false if user.is_admin?

    return user.fetch('agency_roles').all?{|agency_role| can_edit_agency_role?(agency_role.fetch('agency_ref'),agency_role.fetch('agency_location_id'),agency_role.fetch('role'))}
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

  def can_edit_agency_role?(agency_ref, agency_location_id, role)
    # need to have a superior role for agency/location to be able to edit a user with the `agency_role`
    return true if is_admin?
    return true if agency_roles.any?{|agency_role| agency_role.agency_ref == agency_ref && agency_role.is_senior_agency_admin?} && ['AGENCY_ADMIN', 'AGENCY_CONTACT'].include?(role)
    return true if agency_roles.any?{|agency_role| agency_role.agency_ref == agency_ref && agency_role.agency_location_id == agency_location_id && agency_role.is_agency_admin?} && ['AGENCY_CONTACT'].include?(role)

    false
  end

end