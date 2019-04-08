require 'bundler/setup'
Bundler.require

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

require_relative 'storage/base_storage'
require_relative 'storage/db_auth.rb'
require_relative 'storage/users.rb'
require_relative 'storage/sessions.rb'

require_relative 'indexer/indexer'

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

    DB.connect
    AspaceDB.connect

    Ctx.open do
      # Bootstrap an admin user if we need one
      unless Users.user_exists?('admin')
        admin_id = Users.create_admin_user('admin', 'Admin User')

        admin_password = SecureRandom.hex
        DBAuth.set_user_password(admin_id, admin_password)

        # FIXME: logging
        $stderr.puts("The admin password has been set to: #{admin_password}")
      end
    end

    Indexer.start(AppConfig[:solr_url], MapAPI.base_dir(File.join('data', 'indexer', 'indexer.state')))
  end

  private

  def json_response(hash)
    content_type :json
    hash.to_json
  end

end
