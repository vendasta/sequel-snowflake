require 'sequel-snowflake/version'
require 'sequel/adapters/snowflake'

# Register our Snowflake adapter to Sequel's map.
# This allows us to specify the adapter on database connection:
# DB = Sequel.connect(adapter: :snowflake, ...)
# Sequel::Database::ADAPTERS << 'snowflake'
Sequel::ADAPTER_MAP[:snowflake] = Sequel::Snowflake::Database
