Permissions = Struct.new(:is_admin, :groups) do
  def initialize
    self.is_admin = false
    self.groups = []
  end

  def is_admin?
    self.is_admin == true
  end

  def add_group(group)
    self.groups << group
  end

  def location_admin?(agency_id, location_id)
    self.is_admin? || self.groups.any? do |group|
      group.role == 'ADMIN' &&
        ((group.agency_id == agency_id && group.agency_location_id.nil?) ||
         (group.agency_id == agency_id && group.agency_location_id == location_id))
    end
  end

  def to_json(*args)
    to_h.to_json
  end

  def admin_groups
    self.groups.select(&:is_admin?)
  end
end