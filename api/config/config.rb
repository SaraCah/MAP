# create database map character set UTF8mb4 collate utf8mb4_bin;
# grant all on map.* to 'map'@'localhost' identified by 'map123';

# AppConfig[:db_url] = "jdbc:mysql://localhost:3306/map?useUnicode=true&characterEncoding=UTF-8&user=map&password=map123&serverTimezone=UTC"
# AppConfig[:aspace_db_url] = "jdbc:mysql://localhost:3306/archivesspace_test?useUnicode=true&characterEncoding=UTF-8&user=as&password=as123"

# AppConfig[:session_secret] = "randomly_generated_token"

AppConfig[:map_indexer_interval_seconds] = 5
AppConfig[:solr_url] = "http://localhost:8984/solr/map/"
AppConfig[:solr_indexer_state_file] = File.join(File.dirname(__FILE__), "..", "data/solr_indexer_state.dat")
AppConfig[:page_size] = 10

AppConfig[:max_concurrent_xlsx_validations] = 10

# As a long term average you can try one login every 10 seconds
AppConfig[:dbauth_seconds_per_login] = 10

# But you can try 10 in quick succession before we start limiting
AppConfig[:dbauth_max_login_burst] = 10

# You can trigger one SMS per minute on average
AppConfig[:mfa_seconds_per_challenge] = 60

# But we'll let you send 20 in quick succession
AppConfig[:mfa_max_challenge_burst] = 20


# You get 3 minutes and 3 retries on an MFA challenge
AppConfig[:mfa_max_attempts] = 3
AppConfig[:mfa_expire_seconds] = 180


begin
  load File.join(File.dirname(__FILE__), "/config.local.rb")
rescue LoadError
end

# The name of the service as it should appear in communications with end users
AppConfig[:service_name] = "QSA ArchivesGateway"

# The public URL of the service as used by end users.  Password reset links will
# be relative to this URL.
AppConfig[:service_url] = 'http://localhost:3456'


AppConfig[:international_phone_prefix] = "+61"

AppConfig[:password_reset_ttl_seconds] = 86400
AppConfig[:password_reset_subject] = "#{AppConfig[:service_name]} Password Reset"

AppConfig[:email_enabled] = false
AppConfig[:email_override_recipient] = 'qsa-support@gaiaresources.com.au'
AppConfig[:email_from_address] = 'qsa-support@gaiaresources.com.au'

AppConfig[:public_url] = 'http://localhost:3009'