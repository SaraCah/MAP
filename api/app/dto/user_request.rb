class UserRequest
  attr_accessor :username, :name, :password, :errors

  def initialize(hash)
    @username = hash.fetch('username', '')
    @name = hash.fetch('name', '')
    @password = hash.fetch('password', '')
    @is_admin = hash.fetch('is_admin', 'false') == 'true'

    validate!
  end

  def self.parse(hash)
    self.new(hash)
  end

  def is_admin?
    @is_admin
  end

  def valid?
    @errors.empty?
  end

  def validate!
    @errors = []
    @errors << ['username', 'required'] if @username.empty?
    @errors << ['name', 'required'] if @name.empty?
    @errors << ['password', 'required'] if @password.empty?
  end

  def add_error(field, message)
    @errors << [field, message]
  end
end