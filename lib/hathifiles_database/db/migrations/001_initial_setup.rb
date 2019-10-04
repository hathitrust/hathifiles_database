require 'sequel'
require 'hathifiles_database/constants'
include HathifilesDatabase::Constants

Sequel.extension :migration

# Should derive this from the linespec list, but going long and dumb at first
#

#       foreign_table(OCLCTABLE, TO_INT), #  8
#       foreign_table(ISBNTABLE, ISBN_NORMALIZE), #  9
#       foreign_table(ISSNTABLE, ISSN_NORMALIZE), # 10
#       foreign_table(LCCNTABLE, LCCN_NORMALIZE), # 11
#
Sequel.migration do
  up do
    create_table(MAINTABLE) do
      String :htid, primary_key: true, unique: true
      TrueClass :access
      String :rights_code, index: true
      Bignum :bib_num, index: true
      String :description
      String :source
      Stirng :source_bib_num
      String :title
      String :imprint
      String :rights_reason, index: true
      DateTime :rights_timestamp, index: true
      TrueClass :us_gov_doc_flag, index: true
      Fixnum :rights_date_used, index: true
      String :pub_place
      String :lang_code, index: true
      String :bib_fmt, index: true
      String :collection_code, index: true
      String :content_provider_code, index: true
      String :responsible_entity_code
      String :digitization_agent_code
      String :access_profile_code
      String :author
    end

    [OCLCTABLE, ISSNTABLE, ISBNTABLE, LCCNTABLE].each do |table|
      create_table(table) do
        foreign_key :htid, MAINTABLE,
                    type: String, index: true, deferrable: true,
                    on_delete: :cascade
        String :value, index: true
      end
    end

  end
end