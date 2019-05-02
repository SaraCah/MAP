require 'net/http'
require 'net/http/post/multipart'

class MAPAPIClient

  # Documented as thread safe, so we'll share between all threads to reduce the
  # need to connect.
  @http_persistent = Net::HTTP::Persistent.new(name: "map_api_client")

  def self.http_persistent
    @http_persistent
  end

  def http_client
    self.class.http_persistent
  end

  def initialize(session)
    @session = session
  end

  Authentication = Struct.new(:successful, :session_id, :permissions) do
    def successful?
      self.successful
    end
  end

  AgencyRole = Struct.new(:agency_id, :agency_label, :aspace_agency_id, :agency_location_id, :role, :permissions) do
    def self.from_json(json)
      new(json.fetch('agency_id'),
          json.fetch('agency_label'),
          json.fetch('aspace_agency_id'),
          json.fetch('agency_location_id'),
          json.fetch('role'),
          json.fetch('permissions'))
    end

    def is_senior_agency_admin?
      self.role == 'SENIOR_AGENCY_ADMIN'
    end

    def is_agency_admin?
      is_senior_agency_admin? || self.role == 'AGENCY_ADMIN'
    end

    def agency_ref
      "agent_corporate_entity:#{self.aspace_agency_id}"
    end
  end

  Permissions = Struct.new(:is_admin, :agency_roles) do
    def self.from_json(json)
      new(json.fetch('is_admin'),
          json.fetch('agency_roles', []).map {|agency_role_json| AgencyRole.from_json(agency_role_json)})
    end

    def allow_manage_users?
      self.is_admin || is_agency_admin?
    end

    def is_admin?
      self.is_admin
    end

    def allow_manage_locations?
      self.is_admin || is_senior_agency_admin?
    end

    def is_senior_agency_admin?
      self.agency_roles.any?{|agency_role| agency_role.agency_id == Ctx.get.current_location.agency_id && agency_role.is_senior_agency_admin?}
    end

    def is_agency_admin?
      is_senior_agency_admin? || self.agency_roles.any?{|agency_role| agency_role.agency_id == Ctx.get.current_location.agency_id && agency_role.agency_location_id == Ctx.get.current_location.id && agency_role.is_agency_admin?}
    end
  end

  def permission_options
    [:allow_transfers, :allow_file_issue, :allow_set_raps, :allow_change_raps, :allow_restricted_access]
  end

  def authenticate(username, password)
    response = post('/authenticate', username: username, password: password)

    if response['authenticated']
      Authentication.new(true, response['session'], response['permissions'])
    else
      Authentication.new(false)
    end
  end

  User = Struct.new(:username, :name, :is_admin, :is_inactive, :create_time, :agency_roles) do
    def self.from_json(json)
      User.new(json.fetch('username'),
               json.fetch('name'),
               json.fetch('is_admin'),
               json.fetch('is_inactive'),
               json.fetch('create_time'),
               json.fetch('agency_roles').map do |agency, role, location_label|
                 [Agency.from_json(agency), role, location_label]
               end)
    end

    def can_edit?
      return true if Ctx.get.permissions.is_admin?
      return true if Ctx.get.permissions.is_senior_agency_admin?

      agency_roles.any? {|_, role, _|
        role != 'SENIOR_AGENCY_ADMIN'
      }
    end
  end

  Agency = Struct.new(:id, :label, :series_count, :controlled_records) do
    def initialize(*)
      super
      self.series_count ||= 0
      self.controlled_records ||= []
    end

    def self.from_json(json)
      Agency.new(json.fetch('id'),
                 json.fetch('label'),
                 json.fetch('series_count', 0),
                 json.fetch('controlled_records'))
    end


    def to_json(*args)
      to_h.to_json
    end
  end

  PagedResults = Struct.new(:results, :current_page, :max_page) do
    def self.from_json(json, type_class)
      PagedResults.new(json.fetch('results', []).map{|user_json| type_class.included_modules.include?(DTO) ? type_class.from_hash(user_json) : type_class.from_json(user_json)},
                     json.fetch('current_page'),
                     json.fetch('max_page'))
    end
  end


  def users(page = 0)
    PagedResults.from_json(get('/users', page: page), User)
  end

  def groups
    get('/groups')
  end

  def create_user(user)
    response = post('/users/create', user.to_request)
    if response['errors']
      user.add_errors(response['errors'])
    end
  end

  def update_user(user)
    response = post('/users/update', user.to_request)
    if response['errors']
      user.add_errors(response['errors'])
    end
  end

  def user_for_edit(username)
    dto = get('/user-for-edit', {username: username})
    UserUpdateRequest.parse(dto)
  end

  def create_location(location)
    response = post('/locations/create', location.to_hash)
    if response['errors']
      location.add_errors(response['errors'])
    end
  end

  def agency_typeahead(q)
    get('/search/agencies', q: q)
  end

  def get_current_agency
    return nil if Ctx.get.permissions.is_admin?

    Agency.from_json(get('/my-agency', {}))
  end

  AgencyLocation = Struct.new(:id, :name, :agency_id, :create_time, :agency) do
    def self.from_json(json)
      AgencyLocation.new(json.fetch('id'),
                         json.fetch('name'),
                         json.fetch('agency_id'),
                         json.fetch('create_time'),
                         Agency.from_json(json.fetch('agency')))
    end

    def to_search_result
      {
        'id' => id,
        'label' => name
      }
    end

    def to_json(*args)
      to_h.to_json
    end
  end

  def locations(page = 0)
    PagedResults.from_json(get('/locations', page: page), AgencyLocation)
  end

  def locations_for_agency(agency_ref)
    get('/locations_for_agency', {
      'agency_ref' => agency_ref,
    }).map do |json|
      AgencyLocation.from_json(json)
    end
  end

  def permissions_for_current_user
    Permissions.from_json(get('/my-permissions', {}))
  end

  def location_for_current_user
    json = get('/my-location', {})

    return nil if json.nil?

    AgencyLocation.from_json(json)
  end

  def locations_for_current_user
    get('/my-locations', {})
  end

  def set_location(agency_id, location_id)
    post('/set-location', {
      agency_id: agency_id,
      location_id: location_id,
    })
  end

  def transfers(page = 0)
    PagedResults.from_json(get('/transfers', page: page), TransferProposal)
  end

  def create_transfer_proposal(transfer)
    response = post('/transfer_proposals/create', transfer: transfer.to_json)
    response['errors'] || []
  end

  def store_files(files)
    post('/store-files',
         { "file[]" => files.map(&:to_io) },
         :multipart_form_data)
  end

  def get_transfer_proposal(transfer_proposal_id)
    json = get("/transfer_proposals/#{transfer_proposal_id}")

    return nil if json.nil?

    TransferProposal.from_hash(json)
  end

  def update_transfer_proposal(transfer)
    response = post('/transfer_proposals/update', transfer: transfer.to_json)
    response['errors'] || []
  end

  private

  def post(url, params = {}, encoding = :x_www_form_urlencoded)
    uri = build_url(url)

    request = if encoding == :x_www_form_urlencoded
                req = Net::HTTP::Post.new(uri)
                req.form_data = params
                req
              elsif encoding == :multipart_form_data
                Net::HTTP::Post::Multipart.new(uri, params)
              else
                raise "Unknown form encoding: #{encoding.inspect}"
              end

    request['X-MAP-SESSION'] = @session[:api_session_id] if @session[:api_session_id]

    response = http_client.request(uri, request)

    check_errors!(response)

    JSON.parse(response.body)
  end

  def get(url, params = {})
    uri = build_url(url, params)

    request = Net::HTTP::Get.new(uri)
    request['X-MAP-SESSION'] = @session[:api_session_id] if @session[:api_session_id]

    response = http_client.request(uri, request)

    check_errors!(response)

    JSON.parse(response.body)
  end

  class SessionGoneError < StandardError
  end

  def check_errors!(response)
    if !response.code.start_with?('2')
      error = JSON.parse(response.body)

      if error.fetch('SERVER_ERROR', '') == 'Sessions::SessionNotFoundError'
        # Our backend session is gone.  Clear the frontend one too.
        raise SessionGoneError.new
      end

      raise ClientError.new(error)
    end
  end

  def build_url(url, params = nil)
    uri = URI.join(AppConfig[:map_api_url], url)
    if params
      uri.query = URI.encode_www_form(params)
    end
    uri
  end


  class ClientError < StandardError
    def initialize(json)
      @json = json
      super
    end
  end
end
