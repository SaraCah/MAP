require 'bundler/setup'
Bundler.require

require_relative 'common/bootstrap'
require_relative 'storage/db'

Dir.chdir(File.dirname(__FILE__))

$LOAD_PATH << Dir.pwd

class MAPTheAPI < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')
  end

  DB.connect

  get '/' do
    messages = DB.open do |db|
                 db[:hello].select(:message).all.collect{|row| row[:message]}
               end

    json_response({
       hello: messages.join('; ')
     })
  end

  private

  def json_response(hash)
    content_type :json
    hash.to_json
  end

end
