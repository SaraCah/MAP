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

  def users(page = 0)
    get('/users', page: page).map do |json|
      User.from_json(json)
    end
  end

  def create_user(user)
    response = post('/users/create', user.to_hash)
    if response['errors']
      user.add_errors(response['errors'])
    end
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
