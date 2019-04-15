User = Struct.new(:username, :name, :is_admin, :create_time, :agency_permissions) do
  def self.from_row(row, agency_permissions)
    User.new(row[:username],
             row[:name],
             (row[:admin] == 1),
             row[:create_time],
             agency_permissions)
  end

  def to_json(*args)
    to_h.to_json
  end
end