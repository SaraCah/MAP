# create database map character set UTF8mb4 collate utf8mb4_bin;
# grant all on map.* to 'map'@'localhost' identified by 'map123';

begin
  load File.join(File.dirname(__FILE__), "/config.local.rb")
rescue LoadError
  $stderr.puts("Didn't find config.local.rb")
end
