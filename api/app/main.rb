require 'bundler/setup'
Bundler.require

require 'securerandom'

require_relative 'common/bootstrap'
require_relative 'storage/db_pool'
require_relative 'storage/db'
require_relative 'storage/aspace_db'
require_relative 'lib/endpoint'
require_relative 'lib/ctx'

require_relative 'storage/base_storage'
require_relative 'storage/db_auth.rb'
require_relative 'storage/users.rb'
require_relative 'storage/sessions.rb'

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
  end

  configure do
    DB.connect
    AspaceDB.connect

    Ctx.open do
      # Bootstrap an admin user if we need one
      unless Users.user_exists?('admin')
        admin_id = Users.create_user('admin', 'Admin User')

        admin_password = SecureRandom.hex
        DBAuth.set_user_password(admin_id, admin_password)

        # FIXME: logging
        $stderr.puts("The admin password has been set to: #{admin_password}")
      end
    end

  end

  private

  def json_response(hash)
    content_type :json
    hash.to_json
  end

end
