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

require 'rjack-slf4j'

$LOG = RJack::SLF4J["map.api"]

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

require 'securerandom'
require 'fileutils'
require 'net/http'

Dir["models/*.rb"].sort.each {|file| require file }

require 'dto/dto'
require 'dto/transfer_file'
require 'dto/transfer_proposal_series'
require 'dto/transfer_proposal'
require 'dto/transfer'
require 'dto/agency_location_option'
require 'dto/agency_role_dto'
require 'dto/user_dto'
require 'dto/agency_location_dto'
require 'dto/file_issue_request_item'
require 'dto/file_issue_request'

require 'common/bootstrap'
require 'storage/db_pool'
require 'storage/db'
require 'storage/aspace_db'
require 'lib/endpoint'
require 'lib/ctx'
require 'lib/watch_dir_reloader'
require 'lib/search'
require 'lib/solr_indexer'

require 'storage/base_storage'
require 'storage/db_auth'
require 'storage/users'
require 'storage/sessions'
require 'storage/permissions'
require 'storage/agencies'
require 'storage/locations'
require 'storage/transfers'
require 'storage/files'
require 'storage/conversations'
require 'storage/file_issues'
require 'storage/representations'

require 'endpoints/upload_file'
require 'endpoints'

require 'rack/map_logger'

require 'map_validator'


class MAPTheAPI < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')
    config.also_reload File.join('../../maplib', '**', '*.rb')
  end

  configure do
    $LOG.info("Starting application in #{MAPTheAPI.environment} mode")
  end

  configure do
    use Rack::MAPLogger, $LOG
  end

  configure do
    Sequel.database_timezone = :utc
    Sequel.typecast_timezone = :utc

    set :show_exceptions, false

    DB.connect
    AspaceDB.connect

    Ctx.open do
      # Bootstrap an admin user if we need one
      unless Users.user_exists?('admin')
        admin_id = Users.create_admin_user('admin', 'Admin User')
        admin_password = SecureRandom.hex
        DBAuth.set_user_password(admin_id, admin_password)

        $LOG.info("The admin password has been set to: #{admin_password}")
      end
    end

    # Start the indexer thread
    SolrIndexer.start
  end

  configure :development do
    if AppConfig.has_key?(:development_admin_password)
      Ctx.open do
        DBAuth.set_user_password(Users.id_for_username('admin'),
                                 AppConfig[:development_admin_password])

        $LOG.info("Set admin password to '#{AppConfig[:development_admin_password]}' for development mode")
      end
    end
  end

  error do
    $LOG.info("*** Caught unexpected exception: #{$!}")
    $LOG.info($@.join("\n"))
    $LOG.info("=" * 80)
    return [500, {}, {"SERVER_ERROR" => {type: $!.class.to_s, message: $!.to_s}}.to_json]
  end

  private

  def json_response(hash)
    content_type :json
    hash.to_json
  end

end
