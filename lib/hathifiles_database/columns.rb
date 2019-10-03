# frozen_string_literal: true

# Ordered as they are in the hathifiles
require 'library_stdnums'

module HathifilesDatabase
  module Columns
    class Column
      attr_accessor :column, :table, :transform_lambda

      # @param [String] column column name
      # @param [String,Symbol] table Database table this will end up in
      # @param [Proc] transform_lambda Code to transform the data before storing
      def initialize(column, table, transform_lambda = nil)
        @column = column
        @table  = table.to_sym
        @transform_lambda = transform_lambda
      end

      # @return [Boolean]
      def scalar
        raise 'Override #scalar for column types'
      end
    end

    class ScalarColumn < Column
      # @return [Boolean]
      def scalar
        true
      end

      # @param [String] input Data from hathifile
      # @return [String]
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
      VALUE_COLUMN_NAME = "value"
      def initialize(table, transform_lambda)
        super(VALUE_COLUMN_NAME, table, transform_lambda)
      end

      # @return [Boolean]
      def scalar
        false
      end

      # @param [String] comma_delimited_values
      # @return [Array<String>] Split values
      def splitvalues(comma_delimited_values)
        comma_delimited_values.split(/\s*,\s*/)
      end

      # @param [String] comma_delimited_values
      # @return [Array<String>]
      def transform(comma_delimited_values)
        splitvalues(comma_delimited_values).flat_map(&transform_lambda).uniq
      end
    end
  end
end
