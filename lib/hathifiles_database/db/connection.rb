# frozen_string_literal: true

require 'hathifiles_database/line'
require 'hathifiles_database/constants'
require 'hathifiles_database/exceptions'
require 'logger'

require 'sequel'

Sequel.extension(:migration)

module HathifilesDatabase
  class Database
    class Connection < SimpleDelegator

      LOGGER        = Logger.new(STDERR)
      MIGRATION_DIR = Pathname.new(__dir__) + 'migrations'

      def initialize(connection_string)
        @db = Sequel.connect(connection_string)
        __setobj__(@db)
        @main_table     = @db[Constants::MAINTABLE]
        @foreign_tables = Constants::FOREIGN_TABLES.values.each_with_object({}) do |tablename, h|
          h[tablename] = @db[tablename]
        end
      end

      # The upsert is predicated on the database doing a deletion
      # cascade, so deleting (by htid) from the main table
      # will delete from all the foreign tables as well.
      #
      # We take the name of the main table from the constant
      # MAINTABLE and the names of the foreign tables from the
      # keys in the line's #foreign_table_data hash
      # @param []
      def upsert(lines)
        @db.transaction do
          begin
            lines.each_slice(100) do |lns|
              delete(lns)
              add(lns)
            end
          rescue HathifilesDatabase::Exception::WrongNumberOfColumns => e
            LOGGER.warn e
          rescue Sequel::DatabaseError => e
            LOGGER.warn e
            require 'pry'; binding.pry
          end
        end
      end



        def delete(lines)
          @main_table.where(htid: lines.map(&:htid)).delete
        end

        def add(lines)
          lines.map(&:maintable_data).each { |vals| @main_table.insert(vals) }
          @foreign_tables.each_pair do |key, table|
            lines.flat_map { |l| l.foreign_table_data[key].map { |val| [l.htid, val] } }.each { |pair| table.insert(pair) }
          end
        end


        # Create all the tables needed
        def create_tables!
          Sequel::Migrator.run(@db, MIGRATION_DIR)
        end

      end
    end
  end
