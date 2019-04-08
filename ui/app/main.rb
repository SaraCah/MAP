require 'bundler/setup'
Bundler.require

Dir.chdir(File.dirname(__FILE__))

$LOAD_PATH << Dir.pwd

require 'common/app_config'
require 'lib/templates'
require 'views/templates'

require 'lib/ctx'
require 'lib/endpoint'
require 'lib/map_api_client'

require_relative 'endpoints'

class MAPTheApp < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')
    config.after_reload do
      load File.join(Dir.pwd, 'views/templates.rb')
      load File.join(Dir.pwd, 'endpoints.rb')
    end
  end

  use Rack::Session::Cookie, :key => 'map.session',
                             :path => '/',
                             :secret => AppConfig[:session_secret]
end
