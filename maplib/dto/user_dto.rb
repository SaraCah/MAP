class UserDTO
  include DTO

  define_field(:id, Integer, required: false)
  define_field(:username, String)
  define_field(:name, String, validator: proc {|s| (s.nil? || s.empty?) ? "Name can't be blank" : nil})
  define_field(:email, String, validator: proc {|s| UserDTO.validate_email(s)})
  define_field(:password, String, required: false, validator: proc {|s, user| validate_password(s, user)})
  define_field(:is_admin, Boolean, default: false)
  define_field(:is_inactive, Boolean, default: false)
  define_field(:position, String, validator: proc {|s| (s.nil? || s.empty?) ? "Position can't be blank" : nil})
  define_field(:agency_roles, [AgencyRoleDTO], default: [])
  define_field(:created_by, String, required: false)
  define_field(:create_time, Integer, required: false)

  def self.from_row(row, agency_roles = [])
    new(id: row[:id],
        username: row[:username],
        name: row[:name],
        email: row[:email],
        is_admin: (row[:admin] == 1),
        is_inactive: (row[:inactive] == 1),
        agency_roles: agency_roles.map{|agency_permission| AgencyRoleDTO.from_agency_role(agency_permission)},
        created_by: row[:created_by],
        create_time: row[:create_time],
        lock_version: row[:lock_version],
        position: row[:position])
  end

  def self.validate_password(password, user)
    if user.new?
      return "Password can't be blank" if password.empty?
    end

    return nil if password.empty?

    unless Users.valid_password?(password)
      return 'Password must be at least 12 characters in length, contain both upper and lower case letters, and at least one non-letter (numeral, space or punctuation)'
    end

    nil
  end

  def is_admin?
    fetch('is_admin', false)
  end

  def current_user?
    !new? && Ctx.username == fetch('username')
  end

  def agency_roles_valid?(roles)
    return false if is_admin?
    return false if current_user?

    roles.empty?
  end

  def self.validate_email(email)
    if email.nil? || email.empty?
      "Email can't be blank"
    elsif (email =~ URI::MailTo::EMAIL_REGEXP).nil?
      "Email must be a valid email address"
    else
      nil
    end
  end
end