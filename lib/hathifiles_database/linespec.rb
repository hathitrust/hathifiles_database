# frozen_string_literal: true

require "hathifiles_database/exceptions"
require "hathifiles_database/columns"
require "hathifiles_database/line"
require "hathifiles_database/constants"
require "library_stdnums"
require "date"

module HathifilesDatabase
  # A LineSpec is basically an array of columns (maintable or foreign) and
  # ways to get to them.
  class LineSpec
    include Enumerable

    attr_accessor :maintable_name

    # Create a new LineSpec, optionally passing in an array of Scalar- or
    # ForeignColumns, and also optionally having a block of maintable /
    # foreign_table calls to initialize it.
    # @param [Array<HathifilesDatabase::Column] initial_cols An array of column objects
    def initialize(initial_cols = [], maintable_name: Constants::MAINTABLE, add_split_htid: true, &blk)
      @columns = initial_cols
      @count = @columns.size
      instance_eval(&blk) if blk
      @maintable_name = maintable_name
      @add_split_htid = add_split_htid
    end

    def self.db_dump_linespec
      NO_SPLIT_HTID_LINESPEC
    end

    def self.hathifile_linespec
      SPLIT_HTID_LINESPEC
    end

    def each
      return enum_for(:each) unless block_given?
      @columns.each { |x| yield x }
    end

    # Define a column on the "main" table, where all the scalars
    # go.
    # @param [Symbol] column name of the column in the main table
    # @param [Proc, Method] transform Optional proc to massage data before storing
    # @return [LineSpec] self
    def maintable(column, transform = nil)
      add_column Columns::ScalarColumn.new(column, Constants::MAINTABLE, transform)
      self
    end

    # In addition to adding transformed data to the main table for
    # multivalued identifiers, we'll create a linked table with
    # first two columns as [htid, value] (both strings)
    #
    # @param [Symbol] table_alias local name for the foreign table (see Constants)
    # @param [Proc, Method] transform Optional proc to massage data before storing
    # @return [LineSpec] self
    def foreign_table(table_alias, transform = nil)
      add_column Columns::DelimitedColumn.new(Constants::FOREIGN_TABLES[table_alias], transform)
      self
    end

    def add_column(col)
      @columns << col
      @count = @columns.size
    end

    TO_INT = ->(str) do
      begin
        Integer(str, 10)
      rescue
        9999
      end
    end

    ALLOW = ->(str) {
      case str
      when "allow", "1"
        1
      else
        0
      end
    }

    ISBN_NORMALIZE = ->(str) { str.split(/[\s,;|]+/).map { |x| StdNum::ISBN.allNormalizedValues(x) }.flatten.compact.uniq }
    ISSN_NORMALIZE = ->(str) { str.split(/[\s,;|]+/).map { |x| StdNum::ISSN.normalize(x) }.flatten.compact.uniq }
    LCCN_NORMALIZE = ->(str) { [str, StdNum::LCCN.normalize(str)] }
    DATEIFY = ->(str) {
      str.empty? ? nil : Time.parse(str).strftime("%Y-%m-%d %H:%M:%S")
    }

    default_columns = proc do
      maintable(:htid)
      maintable(:namespace)
      maintable(:id)
      maintable(:access, ALLOW)
      maintable(:rights_code)
      maintable(:bib_num, TO_INT)
      maintable(:description)
      maintable(:source)
      foreign_table(:source_bib_num)
      foreign_table(:oclc, TO_INT)
      foreign_table(:isbn, ISBN_NORMALIZE)
      foreign_table(:issn, ISSN_NORMALIZE)
      foreign_table(:lccn, LCCN_NORMALIZE)
      maintable(:title)
      maintable(:imprint)
      maintable(:rights_reason)
      maintable(:rights_timestamp, DATEIFY)
      maintable(:us_gov_doc_flag, TO_INT)
      maintable(:rights_date_used, TO_INT)
      maintable(:pub_place)
      maintable(:lang_code)
      maintable(:bib_fmt)
      maintable(:collection_code)
      maintable(:content_provider_code)
      maintable(:responsible_entity_code)
      maintable(:digitization_agent_code)
      maintable(:access_profile_code)
      maintable(:author)
    end

    SPLIT_HTID_LINESPEC = new(add_split_htid: true, &default_columns)
    NO_SPLIT_HTID_LINESPEC = new(add_split_htid: false, &default_columns)

    def tables
      @columns.map(&:table).uniq
    end

    # Take a raw line and turn it into a Line object
    # @param [String] rawline The raw, tab-delimited line
    # @option [Integer, nil] fileline What line in the file this came from
    # @return [Line]
    def parse(rawline, fileline = nil)
      Line.new(self, split(rawline), fileline: fileline)
    end

    # Split on tabs, add split namespace/htid,  and verify that we have the
    # right number of columns
    #
    # @param [String] rawline Raw line from the hathifile
    # @return [Array<String>]
    def split(rawline)
      vals = rawline.split("\t")
      vals[-1].chomp!

      # add split namespace/id columns after htid, if needed
      if @add_split_htid
        (namespace, id) = vals[0].split(".", 2)
        vals.insert(1, namespace, id)
      end

      # Sometimes the author isn't there so we're one short
      vals.push "" if author_missing?(vals)

      # Everything look ok?
      validate!(vals)

      # Yup
      vals
    end

    AT_LEAST_ONE_NON_SPACE = /\S/
    # The very last column (author) can be correctly set to empty
    # Check for that
    def author_missing?(vals)
      (@count - vals.count == 1) and AT_LEAST_ONE_NON_SPACE.match(vals[-1])
    end

    def validate!(vals)
      raise HathifilesDatabase::Exception::WrongNumberOfColumns.new(htid: vals.first, count: vals.count, expected: @count) if @count != vals.count
    end
  end
end
