class UserUpdateRequest
  attr_accessor :id, :username, :name, :password, :errors, :agencies, :is_admin

  def initialize(hash = {})
    @id = hash.fetch('id', nil)
    @username = hash.fetch('username', '')
    @name = hash.fetch('name', '')
    @password = hash.fetch('password', '')
    @is_admin = hash.fetch('is_admin', 'false') == 'true'
    @agencies = hash.fetch('agency', [])
    @errors = []
  end

  def self.parse(hash)
    self.new(hash)
  end

  def self.from_row(row, agency_roles)
    self.new({
      'id' => row[:id],
      'username' => row[:username],
      'name' => row[:name],
      'is_admin' => ((row[:admin] == 1) ? 'true' : 'false'),
      'agency' => agency_roles.map do |agency_role|
        {
          'id' => agency_role.agency_ref,
          'label' => agency_role.agency_label,
          'role' => agency_role.role,
          'agency_location_id' => agency_role.agency_location_id,
          'agency_location_label' => agency_role.agency_location_label,
          'permission' => agency_role.permissions,
        }
      end
    })
  end

  def new?
    self.id.nil?
  end

  def is_admin?
    @is_admin
  end

  def has_errors?
    !@errors.empty?
  end

  def validate!
    @errors = []
    @errors << ['username', 'required'] if @username.empty?
    @errors << ['name', 'required'] if @name.empty?
    @errors << ['password', 'required'] if new? && @password.empty?
    @errors << ['agency', 'required'] if @agencies.empty? && !@is_admin
  end

  def add_error(field, message)
    @errors << [field, message]
  end

  def add_errors(errors)
    @errors.concat(errors)
  end

  def to_request
    [
      ['user[id]', @id],
      ['user[username]', @username],
      ['user[name]', @name],
      ['user[password]', @password],
      ['user[is_admin]', @is_admin]
    ] + @agencies.map {|agency|
      [
        ["user[agency][][id]", agency[:id]],
        ["user[agency][][role]", agency[:role]],
        ["user[agency][][location_id]", agency[:location_id]],
      ] + Array(agency['permission']).map {|permission|
        [
          ["user[agency][][permission][]", permission]
        ]
      }.flatten(1)
    }.flatten(1)
  end

  def to_hash
    {
      'id' => @id,
      'name' => @name,
      'username' => @username,
      'is_admin' => @is_admin ? 'true' : 'false',
      'agency' => @agencies,
    }
  end

end
