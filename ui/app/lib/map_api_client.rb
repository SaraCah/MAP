require 'net/http'

class MAPAPIClient
  def initialize(session)
    @session = session
  end

  def authenticate(username, password)
    response = post('/authenticate', username: username, password: password)

    return response['session_id'] if response['authenticated']

    raise AuthenticationFailed.new
  end

  class AuthenticationFailed < StandardError; end

  private

  def post(url, params)
    response = Net::HTTP.post_form(build_url(url), params)
    JSON.parse(response.body)
  end

  def build_url(url)
    URI.join('http://localhost:5678', url)
  end
end