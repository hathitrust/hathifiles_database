# frozen_string_literal: true

require "sequel"

# Handles reading and writing hathifiles.hf_log table which is where
# we record state so hathifiles_database as a whole can be date indepenedent.
module HathifilesDatabase
  class Log
    def initialize(connection:)
      @connection = connection
    end

    def add(hathifile:)
      log = log_table.where(hathifile: hathifile)
      if log.update(hathifile: hathifile) != 1
        log.insert(hathifile: hathifile)
      end
    end

    def exist?(hathifile:)
      log_table.where(hathifile: hathifile).count.positive?
    end

    def all_of_type(type:)
      type = type.to_s
      raise "unknown hathifile type '#{type}'" unless ["full", "upd"].include?(type)

      log_table.where(Sequel.like(:hathifile, "%#{type}%")).all
    end

    private

    def log_table
      @connection.rawdb[HathifilesDatabase::Constants::LOG_TABLE]
    end
  end
end
