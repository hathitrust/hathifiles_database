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
      # Write credentials to tempfile. Will be cleaned up when block ends.
      # Tempfile is created with 0600 permissions.
      Tempfile.create(["mysql_defaults_extra", ".ini"]) do |ini|
        connection.logger.debug "writing MySQL INI file at #{ini.path}"
        ini.write(mysql_ini)
        ini.flush
        cmd = dump_cmd(ini_file: ini.path, output_file: output_file)
        connection.logger.debug cmd
        system(cmd, exception: true)
      end
    end

    # Create a TSV database dump based on a hathifile without
    # actually writing anything to the database.
    # Used for constructing the delta between the DB and a new hathifile.
    def dump_from_file(hathifile:, output_directory:)
      datafile = HathifilesDatabase::Datafile.new(hathifile)
      datafile.dump_files_for_data_import(output_directory, nodate_suffix: true)
    end

    private

    def dump_cmd(ini_file:, output_file:)
      # gsub to collapse newlines and multiple space into one line
      <<~END_CMD.gsub(/\s+/, " ")
        mysql
        --defaults-extra-file=#{ini_file}
        --skip-column-names
        --batch
        --raw
        --host=#{ENV["MARIADB_HATHIFILES_RW_HOST"]}
        #{ENV["MARIADB_HATHIFILES_RW_EXTRA_FLAGS"]}
        --execute='#{dump_sql}'
        #{ENV["MARIADB_HATHIFILES_RW_DATABASE"]}
        > #{output_file}
      END_CMD
    end

    # Dump the hf table into a form that can be diffed and resubmitted as a hathifile.
    # No need to do an ORDER BY as we postprocess output using the `sort` command.
    def dump_sql
      @dump_sql ||= <<~END_SQL
        SELECT
          htid, access, rights_code, bib_num, description, source,
          source_bib_num, oclc, isbn, issn, lccn, title, imprint, rights_reason,
          DATE_FORMAT(rights_timestamp, "%Y-%m-%d %H:%i:%s"),
          us_gov_doc_flag, rights_date_used, pub_place, lang_code, bib_fmt,
          collection_code, content_provider_code, responsible_entity_code,
          digitization_agent_code, access_profile_code, author
        FROM hf
      END_SQL
    end

    # The expected INI format provided to --defaults-extra-file=...
    def mysql_ini
      <<~END_INI
        [client]
        user="#{ENV["MARIADB_HATHIFILES_RW_USERNAME"]}"
        password="#{ENV["MARIADB_HATHIFILES_RW_PASSWORD"]}"
      END_INI
    end
  end
end
