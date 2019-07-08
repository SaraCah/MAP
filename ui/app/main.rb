Dir.chdir(File.dirname(__FILE__))
$LOAD_PATH << Dir.pwd

# Development
$LOAD_PATH << File.join(Dir.pwd, '../../maplib')

# Dist
$LOAD_PATH << File.join(Dir.pwd, 'maplib')

Dir.glob('../distlibs/gems/gems/bundler-*/lib').each do |bundler_dir|
  # Force the version of bundler we explicitly installed!
  $LOAD_PATH.unshift(bundler_dir)
end

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
require 'lib/typescript_helper'
require 'lib/js_bundle'
require 'lib/http_utils'

require 'dto/dto'
require 'dto/agency_for_edit'
require 'dto/agency_location_dto'
require 'dto/agency_location_option'
require 'dto/agency_role_dto'
require 'dto/file_issue'
require 'dto/file_issue_item'
require 'dto/file_issue_request'
require 'dto/file_issue_request_item'
require 'dto/membership'
require 'dto/search_request'
require 'dto/search_request_file'
require 'dto/transfer'
require 'dto/transfer_file'
require 'dto/transfer_proposal'
require 'dto/transfer_proposal_series'
require 'dto/user_dto'

require 'endpoints/upload_file'
require 'endpoints'

require 'rack/map_logger'

module Rack
  module Protection
    class Base
      def drop_session(env)
        $LOG.warn("Dropping session: #{env}")
        $LOG.warn("Initiator: #{self}")

        # Original code from lib/rack/protection/base.rb
        session(env).clear if session? env
      end

      def deny(env)
        $LOG.warn("Attack prevented: #{env}")
        $LOG.warn("Initiator: #{self.class}")

        # Original code from lib/rack/protection/base.rb
        [options[:status], {'Content-Type' => 'text/plain'}, [options[:message]]]
      end

    end
  end
end

class MAPTheApp < Sinatra::Base

  configure do
    Dir.glob('buildjs/*.js').each do |js|
      module_name = File.basename(js, '.js')
      JSBundle.add_to_bundle('map_ui_bundle', module_name, js)
    end

    JSBundle.init
  end

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')
    config.also_reload File.join('..', '..', 'maplib', '**', '*.rb')
  end

  configure do
    $LOG.info("Starting application in #{MAPTheApp.environment} mode")
  end

  configure do
    use Rack::MAPLogger, $LOG
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

  use Rack::Deflater

end
