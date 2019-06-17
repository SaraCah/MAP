#AppConfig[:session_secret] = 'randomly_generated_token'
AppConfig[:map_api_url] = 'http://localhost:5678'
AppConfig[:page_size] = 10

begin
  load File.join(File.dirname(__FILE__), "config.local.rb")
rescue LoadError
end
