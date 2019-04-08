require 'bundler/setup'
Bundler.require

Dir.chdir(File.dirname(__FILE__))

$LOAD_PATH << Dir.pwd

require 'lib/templates'
require 'views/templates'

require_relative 'lib/ctx'
require_relative 'lib/endpoint'
require_relative 'lib/map_api_client'

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
                             :secret => 'FIXME'
end
