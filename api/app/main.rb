require 'bundler/setup'
Bundler.require

require_relative 'common/bootstrap'

Dir.chdir(File.dirname(__FILE__))

$LOAD_PATH << Dir.pwd

class MAPTheAPI < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')
  end

  get '/' do
    json_response({
      hello: 'world'
    })
  end

  private

  def json_response(hash)
    content_type :json
    hash.to_json
  end

end
