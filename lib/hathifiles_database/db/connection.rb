# frozen_string_literal: true

require 'hathifiles_database/line'
require 'hathifiles_database/linespec'
require 'hathifiles_database/constants'
require 'hathifiles_database/exceptions'
require 'hathifiles_database/db/writer'
require 'logger'

require 'sequel'

Sequel.extension(:migration)

module HathifilesDatabase
  class DB
    class Connection

      extend HathifilesDatabase::Exception

      LOGGER        = Logger.new(STDERR)
      MIGRATION_DIR = Pathname.new(__dir__) + 'migrations'

      attr_accessor :logger, :rawdb

      # We take the name of the main table from the constant
      # MAINTABLE and the names of the foreign tables from the
      # keys in the line's #foreign_table_data hash
      # @param [String] connection_string A valid Sequel connection string
      #   (see https://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html)
      # @param [#info] logger A logger object that responds to, e.g., `#warn`,
      #   `#info`, etc.
      def initialize(connection_string, logger: LOGGER)
        @rawdb = Sequel.connect(connection_string + '?local_infile=1&CharSet=utf8mb4')
        # __setobj__(@rawdb)
        @main_table     = @rawdb[Constants::MAINTABLE]
        @foreign_tables = Constants::FOREIGN_TABLES.values.each_with_object({}) do |tablename, h|
          h[tablename] = @rawdb[tablename]
        end
        @logger         = logger
      end

      # Update the tables from a file just by directly deleting/inserting
      # the values. It's slow, but not so slow that it's not fine for a normal
      # nightly changefile, and it's a lot less screwing around.
      def update_from_file(filepath, linespec = LineSpec.default_linespec, logger: Constants::LOGGER)
        path = Pathname.new(filepath)
        datafile = HathifilesDatabase::Datafile.new(filepath, linespec, logger: logger)
        upsert(datafile)
      end


      # Update the database with data from a bunch of HathifileDatabase::Line
      # objects.
      # @param [Enumerable<HathifileDatabase::Line>] lines An enumeration of
      #   lines (generally just a datafile, which has the right interface)
      def upsert(lines)
        slice_size            = 100
        log_report_chunk_size = 5000
        mysql_set_foreign_key_checks(:on)
        @rawdb.transaction do
          records = 0
          lines.each_slice(slice_size) do |lns|
            delete_existing_data(lns)
            add(lns)
            records += 1
            logger.info "Inserted/replaced #{records * slice_size} records" if (records * slice_size) % log_report_chunk_size == 0
          rescue HathifilesDatabase::Exception::WrongNumberOfColumns => e
            logger.error e
          rescue Sequel::DatabaseError => e
            logger.error e
            abort
          end
          logger.info "Total inserted: #{records * slice_size}"
        end
      end


      def delete_existing_data(lines)
        @main_table.where(htid: lines.map(&:htid)).delete
        @foreign_tables.each_pair do |_tablename, table|
          table.where(htid: lines.map(&:htid)).delete
        end
      end

      # @param [List<HathifilesDatabase::Line>] lines
      def add(lines)
        lines.each do |line|
          htid = line.htid
          @main_table.insert(line.maintable_data)
          @foreign_tables.each_pair do |tablename, table|
            pairs = line.foreign_table_data[tablename].map { |val| [htid, val] }
            pairs.each do |pair|
              table.insert(pair)
            end
          end
        end
      end

      # Migration targets

      TABLES_CREATED_NO_INDEXES = 100
      DROP_EVERYTHING           = 0


      # Create all the tables needed
      def create_tables!
        Sequel::Migrator.run(@rawdb, MIGRATION_DIR,
                             allow_missing_migration_files: true,
                             target:                        TABLES_CREATED_NO_INDEXES)
      end

      def drop_tables!
        Sequel::Migrator.run(@rawdb, MIGRATION_DIR,
                             allow_missing_migration_files: true,
                             target:                        DROP_EVERYTHING)
      end

      def add_indexes!
        Sequel::Migrator.run(@rawdb, MIGRATION_DIR,
                             allow_missing_migration_files: true)
      end

      def drop_indexes!
        Sequel::Migrator.run(@rawdb, MIGRATION_DIR,
                             allow_missing_migration_files: true,
                             target:                        TABLES_CREATED_NO_INDEXES)
      end

      def recreate_tables!
        drop_tables!
        create_tables!
      end


      # Load the given filepath into the table named.
      # Note that we have to explicitly state that there's isn't an escape character
      # (hence "ESCAPED BY ''") because some fields end with a backslash -- the default
      # escape character.
      #
      # @param [Symbol] tablename
      # @param [Pathname, String] filepath Path to the tab-delimited file to load
      def load_tab_delimited_file(tablename, filepath)
       @rawdb.run("LOAD DATA LOCAL INFILE '#{filepath}' INTO TABLE #{tablename} CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\t' ESCAPED BY ''")
      end


      # Start from scratch
      def start_from_scratch(fullfile, linespec: LineSpec.default_linespec, destination_dir: Dir.tmpdir)

        datafile = Datafile.new(fullfile, linespec)
        logger.info "Dumping files to #{destination_dir} for later import"
        dump_file_paths = datafile.dump_files_for_data_import(destination_dir)

        dbwriter = DB::Writer::InfileDatabaseWriter.new(self, dump_file_paths, logger: logger)
        @logger.info "Loading files from #{destination_dir}"
        dbwriter.import!
        dump_file_paths
      end

      # Turn foreign key checks on or off. Force use of
      # explicit argument to make sure things are on purpose
      # @param [:on, :off] on_or_off Turn them on or off
      # @raise [ArgumentError] if on_or_off isn't :on or :off
      # @return [void]
      def mysql_set_foreign_key_checks(on_or_off)
        case on_or_off
        when :on
          @rawdb.run("SET foreign_key_checks = 1")
        when :off
          @rawdb.run("SET foreign_key_checks = 0")
        else
          raise ArgumentError.new("mysql_set_foreign_key_checks must be send :on or :off")
        end
      end

    end
  end
end
