# frozen_string_literal: true

# Ordered as they are in the hathifiles
require 'library_stdnums'

module HathifilesDatabase
  module Constants

    # Database table names
    MAINTABLE = :hf

    FOREIGN_TABLES = {
      oclc: :hf_oclc,
      isbn: :hf_isbn,
      issn: :hf_issn,
      lccn: :hf_lccn,
    }


  end
end
