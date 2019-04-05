require_relative '../common/bootstrap'

Sequel.connect(AppConfig[:db_url]) do |db|
  Sequel::Migrator.apply(db, MapAPI.base_dir('migrations'))
end

