require "sequel"
require "hathifiles_database/constants"

Sequel.extension :migration

# Should derive this from the linespec list, but going long and dumb at first

#       foreign_table(:source_bib_num) #  7
#       foreign_table(OCLCTABLE, TO_INT), #  8
#       foreign_table(ISBNTABLE, ISBN_NORMALIZE), #  9
#       foreign_table(ISSNTABLE, ISSN_NORMALIZE), # 10
#       foreign_table(LCCNTABLE, LCCN_NORMALIZE), # 11
#
Sequel.migration do
  up do
    create_table(HathifilesDatabase::Constants::MAINTABLE, collate: "utf8_general_ci",
      charset: "utf8") do
      String :htid, null: false
      TrueClass :access
      String :rights_code
      Bignum :bib_num
      String :description
      String :source
      String :source_bib_num, text: true
      String :oclc
      String :isbn, text: true
      String :issn, text: true
      String :lccn
      String :title, text: true
      String :imprint, text: true
      String :rights_reason
      DateTime :rights_timestamp
      TrueClass :us_gov_doc_flag
      Fixnum :rights_date_used
      String :pub_place
      String :lang_code
      String :bib_fmt
      String :collection_code
      String :content_provider_code
      String :responsible_entity_code
      String :digitization_agent_code
      String :access_profile_code
      String :author, text: true
    end

    FOREIGN_TABLES.values.each do |table|
      create_table(table, collate: "utf8_general_ci", charset: "utf8") do
        String :htid, null: false
        String :value, null: false
      end
    end
  end

  down do
    HathifilesDatabase::Constants::FOREIGN_TABLES.values.each do |table|
      drop_table(table)
    end

    drop_table(HathifilesDatabase::Constants::MAINTABLE)
  end
end
