module Sequel
  module Snowflake
    Sequel::Database.set_shared_adapter_scheme(:snowflake, self)

    module DatasetMethods
      # Return an array of strings specifying a query explanation for a SELECT of the
      # current dataset.
      # The options (symbolized, in lowercase) are:
      #   JSON: JSON output is easier to store in a table and query.
      #   TABULAR (default): tabular output is generally more human-readable than JSON output.
      #   TEXT: formatted text output is generally more human-readable than JSON output.
      def explain(opts=OPTS)
        # Load the PrettyTable class, needed for explain output
        Sequel.extension(:_pretty_table) unless defined?(Sequel::PrettyTable)

        explain_with_format = if opts[:tabular]
          "EXPLAIN USING TABULAR"
        elsif opts[:json]
          "EXPLAIN USING JSON"
        elsif opts[:text]
          "EXPLAIN USING TEXT"
        else
          "EXPLAIN"
        end

        ds = db.send(:metadata_dataset).clone(:sql=>"#{explain_with_format} #{select_sql}")
        rows = ds.all
        Sequel::PrettyTable.string(rows, ds.columns)
      end
    end
  end
end
