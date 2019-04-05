require 'sequel'
require_relative 'app_config'
require_relative 'map_api'

Sequel.database_timezone = :utc
Sequel.typecast_timezone = :utc

Sequel.extension :migration
Sequel.extension :core_extensions
