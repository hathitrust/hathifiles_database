require 'hathifiles_database/columns'
require 'library_stdnums'
require 'date'

# Columns as of 20190924
# htid
# access
# rights
# ht_bib_key
# description
# source
# source_bib_num
# oclc_num
# isbn
# issn
# lccn
# title
# imprint
# rights_reason_code
# rights_timestamp
# us_gov_doc_flag
# rights_date_used
# pub_place
# lang
# bib_fmt
# collection_code
# content_provider_code
# responsible_entity_code
# digitization_agent_code
# access_profile_code
# author

module HathifilesDatabase

  class LineSpec

    MAINTABLE = :hathifiles
    OCLCTABLE = :hathifiles_oclc
    ISBNTABLE = :hathifiles_isbn
    ISSNTABLE = :hathifiles_issn
    LCCNTABLE = :hathifiles_lccn

    def self.maintable(column, transform = nil)
      HathifilesDatabase::Columns::ScalarColumn.new(column, MAINTABLE, transform)
    end

    def self.foreign_table(column, table, transform = nil)
      HathifilesDatabase::Columns::DelimitedColumn.new(column, table, transform)
    end

    TO_INT         = ->(str) { Integer(str, 10)}
    ISBN_NORMALIZE = StdNum::ISBN.method :allNormalizedValues
    ISSN_NORMALIZE = StdNum::ISSN.method :normalize
    LCCN_NORMALIZE = ->(str) { [str, StdNum::LCCN.normalize(str)] }
    DATEIFY        = DateTime.method(:parse)

    LINESPEC = [
      maintable(:htid), #  1
      maintable(:access), #  2
      maintable(:rights_code), #  3
      maintable(:bib_num, TO_INT), #  4
      maintable(:description), #  5
      maintable(:source), #  6
      maintable(:source_bib_num), #  7
      foreign_table(:oclc, OCLCTABLE, TO_INT), #  8
      foreign_table(:isbn, ISBNTABLE, ISBN_NORMALIZE), #  9
      foreign_table(:issn, ISSNTABLE, ISSN_NORMALIZE), # 10
      foreign_table(:lccn, LCCNTABLE, LCCN_NORMALIZE), # 11
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
    ]

    NUMBER_OF_COLUMNS = LINESPEC.count
    TABLES            = LINESPEC.map(&:table).uniq

    def self.empty_return_hash
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
    # @param [String] line The raw, tab-delimited line
    # @return [Hash] as described above
    def self.parse(line)
      vals = line.chomp.split(/\t/)
      unless vals.count == NUMBER_OF_COLUMNS
        raise "Whoops. Wrong number of things: vals has #{vals.count} but expected columns is #{NUMBER_OF_COLUMNS}"
      end

      rv = empty_return_hash
      vals.each_with_index do |val, i|
        spec           = LINESPEC[i]
        if spec.scalar
          rv[spec.table] << spec.transform(val)
        else
          rv[spec.table] = spec.transform(val)
        end
      end
      rv[:htid] = vals.first
      rv
    end


  end
end
