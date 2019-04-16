Dir.chdir(File.dirname(__FILE__))
$LOAD_PATH << Dir.pwd

# Development
$LOAD_PATH << File.join(Dir.pwd, '../../maplib')

# Dist
$LOAD_PATH << File.join(Dir.pwd, 'maplib')

require 'bundler/setup'
Bundler.require

$LOG = RJack::SLF4J["map.ui"]

RJack::Logback.configure do
  console = RJack::Logback::ConsoleAppender.new do |a|
    a.target = "System.err"
    a.layout = RJack::Logback::PatternLayout.new do |p|
      p.pattern = "%date [%thread] %-5level %logger{35} - %msg %ex%n"
    end
  end
  RJack::Logback.root.add_appender( console )
  RJack::Logback.root.level = RJack::Logback::INFO
end

require 'digest/sha1'
require 'securerandom'
require 'rack/protection'

require 'common/app_config'
require 'lib/templates'
require 'views/templates'

require 'lib/ctx'
require 'lib/endpoint'
require 'lib/map_api_client'
require 'lib/url_helper'
require 'lib/form_helper'

require 'dto/user_update_request'

require 'endpoints'

class MAPTheApp < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')
    config.also_reload File.join('..', '..', 'maplib', '**', '*.rb')
    config.after_reload do
      load File.join(Dir.pwd, 'views/templates.rb')
      load File.join(Dir.pwd, 'endpoints.rb')
    end
  end

  configure do
    $LOG.info("Starting application in #{MAPTheApp.environment} mode")
  end

  configure :production do
    # In production mode, we want assets to be cached persistently but cleared
    # across releases.
    @cache_nonce = Digest::SHA1.hexdigest((File.read("../VERSION") rescue SecureRandom.hex))
  end

  def self.cache_nonce
    @cache_nonce
  end

  class CacheControl
    def initialize(app)
      @app = app
    end

    def call(env)
      response = @app.call(env)

      if env.fetch('REQUEST_PATH', '') =~ %r{\A/(js|css|webfonts)/} && response[0] == 200
        # Aggressive caching for static assets
        response[1]['Cache-Control'] = "max-age=86400, public"
        response[1]['Expires'] = (Time.now + 86400).utc.rfc2822
      else
        # No caching for anything else
        response[1]['Cache-Control'] = "max-age=0, private"
      end

      response
    end
  end

  use CacheControl


  use Rack::Session::Cookie, :key => 'map.session',

      :path => '/',
      :secret => AppConfig[:session_secret]

  use Rack::Protection
  use Rack::Protection::AuthenticityToken

end
