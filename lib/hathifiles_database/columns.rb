# Ordered as they are in the hathifiles
require 'library_stdnums'

module HathifilesDatabase
  module Columns

    class Column
      attr_accessor :column, :table, :transform_lambda
      def initialize(column, table, transform_lambda=nil)
        @column = column
        @table  = table
        @transform_lambda = transform_lambda
      end
    end

    class ScalarColumn < Column

      def scalar
        true
      end

      def transform(input)
        if transform_lambda
          transform_lambda[input]
        else
          input
        end
      end

    end

    class DelimitedColumn < Column
      attr_accessor :transform_lambda
      def initialize(column, table, transform_lambda)
        super(column, table)
        @transform_lambda = transform_lambda
      end

      def scalar
        false
      end

      def splitvalues(comma_delimited_values)
        comma_delimited_values.split(/\s*,\s*/)
      end

      def transform(comma_delimited_values)
        splitvalues(comma_delimited_values).flat_map(&transform_lambda).uniq
      end
    end

  end
end
