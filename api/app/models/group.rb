GroupPermission = Struct.new(:group_id, :role, :agency_id, :aspace_agency_id, :agency_location_id) do
  def self.from_row(row)
    GroupPermission.new(row[:group_id],
                        row[:role],
                        row[:agency_id],
                        row[:aspace_agency_id],
                        row[:agency_location_id])
  end

  # FIXME ref business
  def agency_ref
    "agent_corporate_entity:#{self.aspace_agency_id}"
  end

  def is_admin?
    self.role == 'ADMIN'
  end

  def to_json(*args)
    to_h.to_json
  end
end