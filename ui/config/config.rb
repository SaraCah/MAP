begin
  load File.join(File.dirname(__FILE__), "config.local.rb")
rescue LoadError
end
