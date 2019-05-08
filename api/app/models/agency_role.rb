AgencyRole = Struct.new(:id, :role, :agency_id, :aspace_agency_id, :agency_location_id, :permissions, :agency_label, :agency_location_label) do
  def self.from_row(row)
    AgencyRole.new(row[:agency_user_id],
                   row[:role],
                   row[:agency_id],
                   row[:aspace_agency_id],
                   row[:agency_location_id],
                   Permissions::AVAILABLE_PERMISSIONS.select{|permission| row[permission] == 1})
  end

  # FIXME ref business
  def agency_ref
    "agent_corporate_entity:#{self.aspace_agency_id}"
  end

  def is_senior_agency_admin?
    self.role == 'SENIOR_AGENCY_ADMIN'
  end

  def is_agency_admin?
    is_senior_agency_admin? || self.role == 'AGENCY_ADMIN'
  end

  def allow_transfers?
    permissions.include?(:allow_transfers)
  end

  def to_json(*args)
    to_h.to_json
  end
end