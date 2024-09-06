# frozen_string_literal: true

# Ordered as they are in the hathifiles
require "library_stdnums"
require "logger"

module HathifilesDatabase
  module Constants
    LOGGER = Logger.new($stderr)

    # Database table names
    MAINTABLE = :hf

    FOREIGN_TABLES = {
      oclc: :hf_oclc,
      isbn: :hf_isbn,
      issn: :hf_issn,
      lccn: :hf_lccn,
      source_bib_num: :hf_source_bib
    }

    MAINTABLE_INDEXES = %i[
      htid
      rights_code
      bib_num
      rights_reason
      rights_timestamp
      us_gov_doc_flag
      rights_date_used
      lang_code
      bib_fmt
      collection_code
      content_provider_code

    ]

    LOG_TABLE = :hf_log
    ALL_TABLES = [MAINTABLE] + FOREIGN_TABLES.values + [LOG_TABLE]
  end
end
