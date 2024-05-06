# frozen_string_literal: true

module HathifilesDatabase
  # TSV export class for hf table and monthly hathifile.
  class Dumper
    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    # Create a TSV dump based on the hf table only.
    # Used for constructing the delta between a monthly hathifile and the current
    # state of the database.
    def dump_current(output_file:)
      sql = <<~END_SQL
        SELECT
          htid, access, rights_code, bib_num, description, source, source_bib_num,
          oclc, isbn, issn, lccn, title, imprint, rights_reason,
          DATE_FORMAT(rights_timestamp, "%Y-%m-%d %H:%i:%s") AS rights_timestamp,
          us_gov_doc_flag, rights_date_used, pub_place, lang_code, bib_fmt,
          collection_code, content_provider_code, responsible_entity_code,
          digitization_agent_code, access_profile_code, author
        FROM hf
      END_SQL

      File.open(output_file, "w:utf-8") do |file|
        connection.rawdb.fetch(sql).each do |line|
          file.puts to_tsv(line)
        end
      end
    end

    # Create a TSV database dump based on a hathifile without
    # actually writing anything to the database.
    # Used for constructing the delta between a monthly hathifile and the current
    # state of the database.
    def dump_from_file(hathifile:, output_directory:)
      datafile = HathifilesDatabase::Datafile.new(hathifile)
      datafile.dump_files_for_data_import(output_directory)
    end

    private

    # Transform a line into tab-delimited form, minimally processing certain Boolean
    # values so the result is integral and not true/false.
    # @param [HathifilesDatabase::Line] line to transform
    def to_tsv(line)
      [
        line[:htid],
        line[:access] ? "1" : "0",
        line[:rights_code],
        line[:bib_num],
        line[:description],
        line[:source],
        line[:source_bib_num],
        line[:oclc],
        line[:isbn],
        line[:issn],
        line[:lccn],
        line[:title],
        line[:imprint],
        line[:rights_reason],
        line[:rights_timestamp],
        line[:us_gov_doc_flag] ? "1" : "0",
        line[:rights_date_used],
        line[:pub_place],
        line[:lang_code],
        line[:bib_fmt],
        line[:collection_code],
        line[:content_provider_code],
        line[:responsible_entity_code],
        line[:digitization_agent_code],
        line[:access_profile_code],
        line[:author]
      ].join("\t")
    end
  end
end
