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
      Authentication.new(true, response['session_id'], response['permissions'])
    else
      Authentication.new(false)
    end
  end

  private

  def post(url, params)
    response = Net::HTTP.post_form(build_url(url), params)
    JSON.parse(response.body)
  end

  def build_url(url)
    URI.join('http://localhost:5678', url)
  end
end
