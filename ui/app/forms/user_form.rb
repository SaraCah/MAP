class UserForm
  attr_accessor :username, :name, :password, :is_admin, :errors

  def initialize(hash = {})
    @username = hash.fetch('username', '')
    @name = hash.fetch('name', '')
    @password = hash.fetch('password', '')
    @is_admin = !!hash.fetch('is_admin', false)
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
    {
      'user[username]' => @username,
      'user[name]' => @name,
      'user[password]' => @password,
      'user[is_admin]' => @is_admin,
    }
  end

end