require 'bundler/setup'
Bundler.require

require 'securerandom'

require_relative 'common/bootstrap'
require_relative 'storage/db'

Dir.chdir(File.dirname(__FILE__))

$LOAD_PATH << Dir.pwd

class MAPTheAPI < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')
  end

  configure do
    DB.connect

    DB.open do |db|
      # Bootstrap an admin user if we need one
      unless db[:user][:username => 'admin']
        admin_id = db[:user].insert(:username => 'admin',
                                    :name => 'Admin User',
                                    :create_time => java.lang.System.currentTimeMillis,
                                    :modified_time => java.lang.System.currentTimeMillis)

        admin_password = SecureRandom.hex

        db[:dbauth].insert(:user_id => admin_id,
                           :pwhash => BCrypt::Password.create(admin_password))

        # FIXME: logging
        $stderr.puts("The admin password has been set to: #{admin_password}")
      end
    end

  end

  get '/' do
    json_response({
       hello: "GREETINGS"
     })
  end

  private

  def json_response(hash)
    content_type :json
    hash.to_json
  end

end
