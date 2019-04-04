require 'bundler/setup'
Bundler.require

Dir.chdir(File.dirname(__FILE__))

$LOAD_PATH << Dir.pwd

require 'lib/templates'
require 'views/templates'

class MAPTheApp < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
    config.also_reload File.join('**', '*.rb')
    config.after_reload do
      load File.join(Dir.pwd, 'views/templates.rb')
    end
  end

  get '/' do
    # These tags get escaped...
    Templates.emit(:hello, :name => "<b>World</b>")
  end

  get '/js/*' do
    filename = request.path.split('/').last
    if File.exist?(file = File.join('js', filename))
      send_file file
    elsif File.exist?(file = File.join('buildjs', filename))
      send_file file
    else
      [404]
    end
  end

  get '/css/*' do
    filename = request.path.split('/').last
    if File.exist?(file = File.join('css', filename))
      send_file file
    else
      [404]
    end
  end

end
