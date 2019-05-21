# create database map character set UTF8mb4 collate utf8mb4_bin;
# grant all on map.* to 'map'@'localhost' identified by 'map123';

# AppConfig[:db_url] = "jdbc:mysql://localhost:3306/map?useUnicode=true&characterEncoding=UTF-8&user=map&password=map123&serverTimezone=UTC"
# AppConfig[:aspace_db_url] = "jdbc:mysql://localhost:3306/archivesspace_test?useUnicode=true&characterEncoding=UTF-8&user=as&password=as123"

# AppConfig[:session_secret] = "randomly_generated_token"

AppConfig[:map_indexer_interval_seconds] = 5
AppConfig[:solr_url] = "http://localhost:8984/solr/map/"
AppConfig[:solr_indexer_state_file] = File.join(File.dirname(__FILE__), "..", "data/solr_indexer_state.dat")
AppConfig[:page_size] = 10

begin
  load File.join(File.dirname(__FILE__), "/config.local.rb")
rescue LoadError
end
