# frozen_string_literal: true

require 'hathifiles_database/exceptions'
require 'hathifiles_database/columns'
require 'hathifiles_database/line'
require 'library_stdnums'
require 'date'


module HathifilesDatabase

  # Where all the actual columns are defined.
  class LineSpec

    MAINTABLE = :hathifiles
    OCLCTABLE = :hf_oclc
    ISBNTABLE = :hf_isbn
    ISSNTABLE = :hf_issn
    LCCNTABLE = :hf_lccn

    # Define a column on the "main" table, where all the scalars
    # go.
    # @param [Symbol] column name of the column in the main table
    # @param [Proc, Method] transform Optional proc to massage data before storing
    # @return [ScalarColumn]
    def self.maintable(column, transform = nil)
      HathifilesDatabase::Columns::ScalarColumn.new(column, MAINTABLE, transform)
    end

    # Define a column for a linked table, which will always at least have the
    # first two columns as [htid, value] (both strings)
    # @param [Symbol] table name of the foreign table
    # @param [Proc, Method] transform Optional proc to massage data before storing
    # @return [ForeignColumn]
    def self.foreign_table(table, transform = nil)
      HathifilesDatabase::Columns::DelimitedColumn.new(table, transform)
    end

    TO_INT = ->(str) { Integer(str, 10) }
    ISBN_NORMALIZE = StdNum::ISBN.method :allNormalizedValues
    ISSN_NORMALIZE = StdNum::ISSN.method :normalize
    LCCN_NORMALIZE = ->(str) { [str, StdNum::LCCN.normalize(str)] }
    DATEIFY = DateTime.method(:parse)

    LINESPEC = [
      maintable(:htid), #  1
      maintable(:access), #  2
      maintable(:rights_code), #  3
      maintable(:bib_num, TO_INT), #  4
      maintable(:description), #  5
      maintable(:source), #  6
      maintable(:source_bib_num), #  7
      foreign_table(OCLCTABLE, TO_INT), #  8
      foreign_table(ISBNTABLE, ISBN_NORMALIZE), #  9
      foreign_table(ISSNTABLE, ISSN_NORMALIZE), # 10
      foreign_table(LCCNTABLE, LCCN_NORMALIZE), # 11
      maintable(:title), # 12
      maintable(:imprint), # 13
      maintable(:rights_reason), # 14
      maintable(:rights_timestamp, DATEIFY), # 15
      maintable(:us_gov_doc_flag, TO_INT), # 16
      maintable(:rights_date_used, TO_INT), # 17
      maintable(:pub_place), # 18
      maintable(:lang_code), # 19
      maintable(:bib_fmt), # 20
      maintable(:collection_code), # 21
      maintable(:content_provider_code), # 22
      maintable(:responsible_entity_code), # 23
      maintable(:digitization_agent_code), # 24
      maintable(:access_profile_code), # 25
      maintable(:author) # 26
    ].map(&:freeze)

    NUMBER_OF_COLUMNS = LINESPEC.count
    TABLES = LINESPEC.map(&:table).uniq

    def empty_return_hash
      {
        MAINTABLE => [],
        OCLCTABLE => nil,
        ISBNTABLE => nil,
        ISSNTABLE => nil,
        LCCNTABLE => nil
      }
    end

    # Take a line and turn it into a hash that looks like
    #  {
    #   :maintable => row,
    #   :oclc => [oclc1, oclc2, ...],
    # }
    # @param [String] rawline The raw, tab-delimited line
    # @param [Array<Column>] specs The line specs
    # @option [Integer, nil] fileline What line in the file this came from
    # @return [Line]
    def parse(rawline, specs = LINESPEC, fileline = nil)
      Line.new(specs, split(rawline), fileline: fileline)
    end

    # Split on tabs and verify that we have the right number of columns
    # @param [String] rawline Raw line from the hathifile
    # @return [Array<String>]
    def split(rawline)
      vals = rawline.chomp.split(/\t/)
      if vals.count != NUMBER_OF_COLUMNS
        raise WrongNumberOfColumns.new(htid: vals.first)
      else
        vals
      end
    end
  end
end

