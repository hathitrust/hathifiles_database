# frozen_string_literal: true

require "hathifiles_database/log"

module HathifilesDatabase
  class Hathifiles
    attr_reader :hathifiles_directory, :connection

    def initialize(
      hathifiles_directory: ENV["HATHIFILES_DIR"],
      connection: HathifilesDatabase.new(ENV["HATHIFILES_MYSQL_CONNECTION"])
    )
      @hathifiles_directory = hathifiles_directory
      @connection = connection
    end

    def missing_full_hathifiles
      return [] if latest_full_hathifile.nil?
      return [] if log.exist?(hathifile: latest_full_hathifile)

      [latest_full_hathifile]
    end

    # If we've already logged the monthly load then we can just load the missing files.
    # If we're starting from a monthly then it seems prudent to load all of the files.
    # Under normal circumstances it is unlikely to make a difference.
    # In a degenerate case it still may be necessary to manually load files.
    def missing_update_hathifiles
      return @missing_update_hathifiles if @missing_update_hathifiles

      @missing_update_hathifiles = update_hathifiles
      if log.exist?(hathifile: latest_full_hathifile)
        seen = log.all_of_type(type: "upd").map { |row| row[:hathifile] }
        @missing_update_hathifiles -= seen
      end
      @missing_update_hathifiles
    end

    private

    def latest_full_hathifile
      max = Dir.glob(File.join(hathifiles_directory, "hathi_full*")).max
      @latest_full_hathifile ||= max ? File.basename(max) : nil
    end

    # Get only the updates with datestamps after the full file.
    # If the full file does not exist in the log then we will process it and all the subsequent updates.
    # If it does, then only process the updates that are not in the log.
    def update_hathifiles
      @update_hathifiles ||= Dir.glob(File.join(hathifiles_directory, "hathi_upd*"))
        .select { |hathifile| hathifile.match(/hathi_upd_(\d{8})/)[1] > latest_full_hathifile_date }
        .map { |hathifile| File.basename(hathifile) }
    end

    def latest_full_hathifile_date
      @latest_full_hathifile_date ||= latest_full_hathifile.match(/hathi_full_(\d{8})/)[1]
    end

    def log
      @log ||= HathifilesDatabase::Log.new(connection: connection)
    end
  end
end
