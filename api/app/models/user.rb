User = Struct.new(:username, :name, :is_admin, :create_time, :agency_roles) do
  def self.from_row(row, agency_roles)
    User.new(row[:username],
             row[:name],
             (row[:admin] == 1),
             row[:create_time],
             agency_roles)
  end

  def to_json(*args)
    to_h.to_json
  end
end