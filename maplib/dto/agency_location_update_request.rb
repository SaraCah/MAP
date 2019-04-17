class AgencyLocationUpdateRequest
  attr_accessor :name, :agency, :agency_label, :agency_ref, :errors

  def initialize(hash = {})
    @id = hash.fetch('id', nil)
    @name = hash.fetch('name', '')
    @agency_ref = hash.fetch('agency_ref', '')
    @agency_label = hash.fetch('agency_label', '')
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

  def agency
    {
      'id' => self.agency_ref,
      'label' => self.agency_label,
    }
  end

  def validate!
    @errors = []
    @errors << ['name', 'required'] if @name.empty?
    @errors << ['agency_ref', 'required'] if @agency_ref.empty?
  end

  def add_error(field, message)
    @errors << [field, message]
  end

  def add_errors(errors)
    @errors.concat(errors)
  end

  def to_hash
    [
      ['location[name]', @name],
      ['location[agency_ref]', @agency_ref],
    ]
  end
end
