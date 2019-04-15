class UserUpdateRequest
  attr_accessor :username, :name, :password, :errors, :agencies, :is_admin

  def initialize(hash = {})
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
    @errors << ['password', 'required'] if @password.empty?
    @errors << ['agency', 'required'] if @agencies.empty? && !@is_admin
  end

  def add_error(field, message)
    @errors << [field, message]
  end

  def add_errors(errors)
    @errors.concat(errors)
  end

  def to_hash
    [
      ['user[username]', @username],
      ['user[name]', @name],
      ['user[password]', @password],
      ['user[is_admin]', @is_admin]
    ] + @agencies.map {|agency|
      [
        ["user[agency][][id]", agency[:id]],
        ["user[agency][][role]", agency[:role]],
        ["user[agency][][location_id]", agency[:location_id]],
      ]
    }.flatten(1)
  end

end
