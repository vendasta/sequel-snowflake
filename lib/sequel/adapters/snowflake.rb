require 'sequel'
require 'sequel/adapters/odbc'
require_relative 'shared/snowflake'

# A lightweight adapter providing Snowflake support for the `sequel` gem.
# The only difference between this and the Sequel-provided ODBC adapter is
# how we interpret the response data, which is handled by the Dataset class.
module Sequel
  module Snowflake
    class Database < Sequel::ODBC::Database
      # Default varchar size is the maximum (https://docs.snowflake.com/en/sql-reference/data-types-text.html#varchar)
      def default_string_column_size
        16777216
      end

      def dataset_class_default
        Sequel::Snowflake::Dataset
      end
      private :dataset_class_default
    end

    # A custom Sequel Dataset class crafted specifically to handle Snowflake results.
    class Dataset < Sequel::ODBC::Dataset
      include Sequel::Snowflake::DatasetMethods

      def fetch_rows(sql)
        execute(sql) do |s|
          i = -1
          cols = s.columns(true).map{|c| [output_identifier(c.name), c.type, c.scale, i+=1]}
          columns = cols.map{|c| c[0]}
          self.columns = columns
          s.each do |row|
            hash = {}
            cols.each{|n,type,scale,j| hash[n] = convert_snowflake_value(row[j], type, scale)}
            yield hash
          end
        end
        self
      end

      # This is similar to the ODBC adapter's Dataset#convert_odbc_value, except for some special casing
      # around Snowflake numerics, which come in through ODBC as Strings instead of Numbers.
      # In those cases, we need to examine the column type as well as the scale,
      # to properly convert Integers and Doubles.
      # Partially inspired by https://github.com/instacart/odbc_adapter.
      #
      # @param value The actual value to be converted
      # @param column_type The type assigned to that value's column
      # @param scale [Number] The number of digits to the right of the decimal point, if this is a SQL_DECIMAL value.
      def convert_snowflake_value(value, column_type, scale)
        return nil if value.nil? # Null values need no conversion.

        case value
        when ::ODBC::TimeStamp
          db.to_application_timestamp(
            [value.year, value.month, value.day, value.hour, value.minute, value.second, value.fraction]
          )
        when ::ODBC::Time
          Sequel::SQLTime.create(value.hour, value.minute, value.second)
        when ::ODBC::Date
          Date.new(value.year, value.month, value.day)
        else
          if column_type == ::ODBC::SQL_BIT
            value == 1
          elsif column_type == ::ODBC::SQL_DECIMAL && scale.zero?
            value.to_i
          elsif column_type == ::ODBC::SQL_DECIMAL && !scale.zero?
            value.to_f
          else
            # Ensure strings are in UTF-8: https://stackoverflow.com/q/65946886
            value.is_a?(String) ? value.force_encoding('UTF-8') : value
          end
        end
      end
      private :convert_snowflake_value

      # Snowflake can insert multiple rows using VALUES (https://stackoverflow.com/q/64578007)
      def multi_insert_sql_strategy
        :values
      end
      private :multi_insert_sql_strategy
    end
  end
end
