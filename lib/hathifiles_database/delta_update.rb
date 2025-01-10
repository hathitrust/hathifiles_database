# frozen_string_literal: true

require "tempfile"
require "zlib"

require "hathifiles_database/dumper"
require "hathifiles_database/hathifiles"

module HathifilesDatabase
  # Updates the hf family of database tables with a monthly or update hathifile.
  # Tries to avoid disruption and thrashing by computing a delta using the
  # current hathifile and the state of the database and diffing
  # two derivative files based on the current hf table and the hathifile
  # to be inserted.

  # By sorting and comparing these dumps we arrive at a "changes" file
  # and (monthly) a "deletions" file which can be submitted to the `Connection` class.

  # Here are the files that are generated in tmpdir in the process of running an update:
  #
  #  hf_currentYYYYMMDD-* (a `Tempfile`-generated filename)
  #    Unsorted dump of the current hf table created by `mysql` executable
  #
  #  hf_current.txt
  #    Sorted version of the above
  #
  #  hf_current_ids.txt
  #    Just the sorted HTIDs from hf_current.txt, used to generate statistics-oriented files below.
  #
  #  hf.tsv (and other *.tsv files)
  #    Formatted hathifile info in database form provided by Dumper and ultimately Datafile
  #    This file is sorted to create `*.new` (below), and all the TSVs are subsequently deleted.
  #
  #  hathi_{upd,full}_YYMMDD.txt.gz.new
  #    Sorted dump of the above
  #
  #  hathi_{upd,full}_YYMMDD.txt.gz.new_ids
  #    Just the sorted HTIDs from *.new
  #
  #  hathi_{upd,full}_YYMMDD.txt.gz.all_changes
  #    `*.new` - hf_current.txt, modified or added records
  #    ===================================================================================
  #    Primary file submitted to the `Connection` class to modify the database.
  #    ===================================================================================
  #
  #  hathi_{upd,full}_YYMMDD.txt.gz.all_changes_ids
  #    Just the sorted HTIDs from *.all_changes
  #
  #  hathi_{upd,full}_YYMMDD.txt.gz.additions
  #    HTIDs not in `hf_current_ids.txt` but in the hathifile's `*.new_ids`
  #
  #  hathi_{upd,full}_YYMMDD.txt.gz.updates
  #    HTIDs common to `hf_current_ids.txt` and `*.all_changes_ids`
  #
  #  hathi_{upd,full}_YYMMDD.txt.gz.deletions
  #    hf_current.txt HTIDs - hf_new.txt HTIDs
  #    Note: only created for full hathifiles, not updates
  #    ===================================================================================
  #    When available, submitted to the `Connection` class to modify the database.
  #    ===================================================================================
  #

  # See exe/hathifiles_database_full_update for minimal usage example.
  class DeltaUpdate
    attr_reader :connection, :hathifile, :output_directory, :dumper

    def initialize(connection:, hathifile:, output_directory:)
      @connection = connection
      @hathifile = hathifile.to_s # in case it's a Pathname
      @output_directory = output_directory
      @dumper = Dumper.new(connection)
      @full = File.basename(hathifile).match? Hathifiles::FULL_RE
    end

    # Assembles the additions and deletions files and submits them to the connection
    # for application to the database.
    def run(&block)
      connection.update_from_file(
        all_changes,
        deletes_file: deletions,
        hathifile_to_log: hathifile,
        &block
      )
    end

    # Dumps the current contents of hf table to a file and sorts it.
    # @return [String] path to sorted dump of the current hf database
    def current_dump
      @current_dump ||= File.join(output_directory, "hf_current.txt").tap do |output_file|
        Tempfile.create("hf_current") do |tempfile|
          connection.logger.info "dumping current hf table to #{tempfile.path}"
          dumper.dump_current(output_file: tempfile.path)
          tempfile.flush
          run_system_command "sort #{tempfile.path} > #{output_file}"
        end
      end
    end

    # Extract the HTIDs from `new_dump` into hf_new_ids.txt and sort the result.
    # @return [String] path to sorted dump based on monthly hathifile
    def current_ids
      @current_ids ||= File.join(output_directory, "hf_current_ids.txt").tap do |output_file|
        connection.logger.info "extracting ids from #{current_dump} to #{output_file}"
        run_system_command "cut -f 1 #{current_dump} | sort > #{output_file}"
      end
    end

    # Dumps a simulated hf table from a hathifile and sorts it.
    # Also dumps the auxiliary tables but we ignore them.
    # @return [String] path to sorted dump based on the new hathifile
    def new_dump
      @new_dump ||= hathifile_derivative("new").tap do |output_file|
        connection.logger.info "dumping new database values from #{hathifile} to #{output_directory}"
        dump_file_paths = dumper.dump_from_file(hathifile: hathifile, output_directory: output_directory)
        run_system_command "sort #{dump_file_paths[:hf]} > #{output_file}"
        # Delete the dump TSVs since we no longer need them
        dump_file_paths.each_value do |value|
          FileUtils.rm(value)
        end
      end
    end

    # Extract the HTIDs from `.new` into sorted `new_ids` file.
    # @return [String] path to sorted dump based on monthly hathifile
    def new_ids
      @new_ids ||= hathifile_derivative("new_ids").tap do |output_file|
        connection.logger.info "extracting ids from #{new_dump} to #{output_file}"
        run_system_command "cut -f 1 #{new_dump} | sort > #{output_file}"
      end
    end

    # Creates .all_changes file with only the records added or changed in new_dump
    # but not current_dump. This file can be loaded just like an ordinary daily update.
    # @return [String] path to changes file
    def all_changes
      @all_changes ||= hathifile_derivative("all_changes").tap do |output_file|
        comm_cmd = "comm -13 #{current_dump} #{new_dump} > #{output_file}"
        run_system_command comm_cmd
      end
    end

    # Creates .all_changes_ids file with only the HTIDs added or changed in new_dump
    # but not current_dump. This is used in generating `updates` for statistics.
    # @return [String] path to changes file
    def all_changes_ids
      @all_changes_ids ||= hathifile_derivative("all_changes_ids").tap do |output_file|
        connection.logger.info "extracting ids from #{all_changes} to #{output_file}"
        run_system_command "cut -f 1 #{all_changes} | sort > #{output_file}"
      end
    end

    # Creates .additions file with only the records added by the new hathifile,
    # not currently in database. This file is only for gathering stats.
    def additions
      @additions ||= hathifile_derivative("additions").tap do |output_file|
        # Additions are HTIDs not in the current ids but in the new ids
        # We want Lines only in file2 (new ids)
        comm_cmd = "comm -13 #{current_ids} #{new_ids} > #{output_file}"
        run_system_command comm_cmd
      end
    end

    # Creates .updates file with only the records modified by the new hathifile,
    # already in database but with different data. This file is only for gathering stats.
    def updates
      @updates ||= hathifile_derivative("updates").tap do |output_file|
        # Updates are HTIDs common to both files, i.e., column 3 only
        comm_cmd = "comm -12 #{current_ids} #{all_changes_ids} > #{output_file}"
        run_system_command comm_cmd
      end
    end

    # Creates .deletions file with only the records in the database but not present
    # in the new hathifile. This file is a newline-delimited list of HTIDs.
    # Does not do deletions when the hathifile is an update -- that would trash the hf table!
    # @return [String] path to deletions file or nil when processing an update file
    def deletions
      return nil unless @full

      @deletions ||= hathifile_derivative("deletions").tap do |output_file|
        comm_cmd = "comm -23 #{current_ids} #{new_ids} > #{output_file}"
        run_system_command comm_cmd
      end
    end

    # Struct with the number of lines in the hathifile, the changes, and deletions.
    # This is for getting a handle on performance of delta computation vs wholesale replacement
    # of database contents.
    def statistics
      @statistics ||= {
        additions: linecount(path: additions),
        all_changes: linecount(path: all_changes),
        deletions: linecount(path: deletions),
        hathifile_lines: gzip_linecount(path: hathifile),
        updates: linecount(path: updates)
      }
    end

    private

    # @return [String] path to hathifile derivative with suffix
    def hathifile_derivative(suffix)
      File.join(output_directory, File.basename(hathifile)) + "." + suffix
    end

    # Log a shellout and execute it
    def run_system_command(cmd)
      connection.logger.info cmd
      system(cmd, exception: true)
    end

    def linecount(path:)
      return 0 if path.nil?

      `wc -l "#{path}"`.strip.split(" ")[0].to_i
    end

    def gzip_linecount(path:)
      Zlib::GzipReader.open(path, encoding: "utf-8") { |gz| gz.count }
    end
  end
end
