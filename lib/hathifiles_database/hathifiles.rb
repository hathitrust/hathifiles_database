# frozen_string_literal: true

# A class responsible for identifying hathifiles that have not yet been loaded into the
# `hathifiles` database.
#
# It computes a delta between the files in `HATHIFILES_DIR` and those recorded in the
# `hathifiles.hf_log` table.
#
# The most recent monthly "full" file is used as a waypoint -- we are not interested in
# any "upd" files older than it.
#
# Note: the two public methods `missing_full_hathifiles` and `missing_update_hathifiles`
# return Arrays of filenames, not paths. Internally we try to use basenames instead of
# paths as much as possible, just to cut out some of the noise.

require "hathifiles_database/log"

module HathifilesDatabase
  class Hathifiles
    FULL_RE = /^hathi_full_(\d{8})\.txt\.gz$/
    UPD_RE = /^hathi_upd_(\d{8})\.txt\.gz$/

    attr_reader :hathifiles_directory, :connection

    def initialize(
      hathifiles_directory: ENV["HATHIFILES_DIR"],
      # FIXME: don't use connection string, so either use Canister or don't offer a default.
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

      @missing_update_hathifiles = latest_update_hathifiles
      if log.exist?(hathifile: latest_full_hathifile)
        # Get all updates ever loaded -- we're mainly interested in the ones
        # from previous days.
        seen = log.all_of_type(type: "upd").map { |row| row[:hathifile] }
        @missing_update_hathifiles -= seen
      end
      @missing_update_hathifiles
    end

    private

    def latest_full_hathifile
      @latest_full_hathifile ||= all_of_type(type: "full").max
    end

    def latest_full_hathifile_date
      @latest_full_hathifile_date ||= latest_full_hathifile.match(FULL_RE)[1]
    end

    # Get only the updates with datestamps on or after the full file's.
    # If the full file does not exist in the log then we will process it and all the subsequent updates.
    # If it does, then only process the updates that are not in the log.
    def latest_update_hathifiles
      @latest_update_hathifiles ||= all_of_type(type: "upd")
        .select { |hathifile| hathifile.match(UPD_RE)[1] >= latest_full_hathifile_date }
        .sort
    end

    # Returns the basenames of all "full" or "upd" files.
    # @param type [String|Symbol] "full" or "upd"
    # @return [Array<String>] hathifile basenames in arbitrary order
    def all_of_type(type:)
      type = type.to_s
      re = (type == "full") ? FULL_RE : UPD_RE
      Dir.glob(File.join(hathifiles_directory, "*"))
        .map { |hathifile| File.basename(hathifile) }
        .select { |hathifile| hathifile.match? re }
    end

    def log
      @log ||= HathifilesDatabase::Log.new(connection: connection)
    end
  end
end
