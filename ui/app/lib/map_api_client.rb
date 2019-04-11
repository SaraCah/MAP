require 'net/http'

class MAPAPIClient
  def initialize(session)
    @session = session
  end

  Authentication = Struct.new(:successful, :session_id, :permissions) do
    def successful?
      self.successful
    end
  end

  Permissions = Struct.new(:is_admin, :agencies) do
    def self.from_json(json)
      new(json.fetch('is_admin'),
          json.fetch('agencies'))
    end

    def allow_manage_users?
      self.is_admin || self.agencies.any? {|agency_ref, role| role == 'ADMIN'}
    end

    def is_admin?
      self.is_admin
    end
  end


  def authenticate(username, password)
    response = post('/authenticate', username: username, password: password)

    if response['authenticated']
      Authentication.new(true, response['session'], response['permissions'])
    else
      Authentication.new(false)
    end
  end

  User = Struct.new(:username, :name, :create_time, :permissions) do
    def self.from_json(json)
      User.new(json['username'],
               json['name'],
               json['create_time'],
               json['permissions'])
    end
  end

  Agency = Struct.new(:id, :label, :series_count) do
    def self.from_json(json)
      Agency.new(json.fetch('id'),
                 json.fetch('label'),
                 json.fetch('series_count'))
    end
  end

  PagedUsers = Struct.new(:users, :current_page, :max_page) do
    def self.from_json(json)
      PagedUsers.new(json.fetch('users', []).map{|user_json| User.from_json(user_json)},
                     json.fetch('current_page'),
                     json.fetch('max_page'))
    end
  end


  def users(page = 0)
    PagedUsers.from_json(get('/users', page: page))
  end

  def create_user(user)
    response = post('/users/create', user.to_hash)
    if response['errors']
      user.add_errors(response['errors'])
    end
  end

  def agency_typeahead(q)
    get('/search/agencies', q: q)
  end

  def get_my_agencies
    get('/my-agencies', {}).map do |json|
      Agency.from_json(json)
    end
  end

  def permissions_for_current_user
    Permissions.from_json(get('/my-permissions', {}))
  end

  private

  def post(url, params = {})
    uri = build_url(url)

    request = Net::HTTP::Post.new(uri)
    request['X-MAP-SESSION'] = @session[:api_session_id] if @session[:api_session_id]
    request.set_form_data(params)

    response = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(request)
    }

    check_errors!(response)

    JSON.parse(response.body)
  end

  def get(url, params)
    uri = build_url(url, params)

    request = Net::HTTP::Get.new(uri)
    request['X-MAP-SESSION'] = @session[:api_session_id] if @session[:api_session_id]

    response = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(request)
    }

    check_errors!(response)

    JSON.parse(response.body)
  end

  def check_errors!(response)
    if !response.code.start_with?('2')
      raise ClientError.new(JSON.parse(response.body))
    end
  end

  def build_url(url, params = nil)
    uri = URI.join('http://localhost:5678', url)
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
