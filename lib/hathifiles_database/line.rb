# frozen_string_literal: true

require 'hathifiles_database/exceptions'
require 'hathifiles_database/columns'
require 'hathifiles_database/linespec'

module HathifilesDatabase
  class Line
    attr_accessor :htid, :maintable_data, :foreign_table_data

    def initialize(specs, values, fileline: nil)
      @fileline = fileline
      @htid = values.first
      @maintable_data = []
      @foreign_table_data = {}
      add_values!(specs, values)
    end

    def empty?
      @htid.nil? or @htid == ''
    end

    # @param [Array<Column>] specs List of column specs
    # @param [Array<String>] values Values from the line in the hathifile
    def add_values!(specs, values)
      specs.each_with_index do |spec, index|
        if spec.scalar
          add_to_main_table spec.transform(values[index])
        else
          add_to_main_table(spec.transform(values[index]).join(','))
          add_to_foreign_table(spec.table, spec.transform(values[index]))
        end
      end
    end

    def add_to_main_table(value)
      @maintable_data << value
    end

    def add_to_foreign_table(table, values)
      @foreign_table_data[table] = values.compact
    end

  end
end
