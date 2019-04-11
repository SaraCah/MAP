class UserForm
  attr_accessor :username, :name, :password, :is_admin, :errors, :agencies

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

  def add_errors(errors)
    @errors = errors
  end

  def has_errors?
    !@errors.empty?
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
        ["user[agency][][role]", agency[:role]]
      ]
    }.flatten(1)
  end

end
