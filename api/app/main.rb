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

require_relative 'common/bootstrap'
require_relative 'storage/db_pool'
require_relative 'storage/db'
require_relative 'storage/aspace_db'
require_relative 'lib/endpoint'
require_relative 'lib/ctx'
require_relative 'lib/watch_dir_reloader'
require_relative 'lib/search'

require_relative 'storage/base_storage'
require_relative 'storage/db_auth.rb'
require_relative 'storage/users.rb'
require_relative 'storage/sessions.rb'

require_relative 'indexer/indexer'

require_relative 'dto/user_request'

require_relative 'endpoints.rb'

Dir.chdir(File.dirname(__FILE__))

$LOAD_PATH << Dir.pwd

class MAPTheAPI < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')

    config.after_reload do
      load File.join(Dir.pwd, 'endpoints.rb')
    end

    WatchDirReloader.new(["indexer"]).start
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

    Indexer.start(AppConfig[:solr_url], MapAPI.base_dir(File.join('data', 'indexer', 'indexer.state')))
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
    return [500, {}, {"SERVER_ERROR" => $!.to_s}.to_json]
  end

  private

  def json_response(hash)
    content_type :json
    hash.to_json
  end

end
