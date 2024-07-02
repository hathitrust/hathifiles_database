# frozen_string_literal: true

require "tempfile"

require "hathifiles_database/dumper"

module HathifilesDatabase
  # Updates the hf family of database tables with a full monthly hathifile.
  # Tries to avoid disruption and thrashing by computing a delta using the
  # current monthly hathifile and the state of the database and diffing
  # two derivative files based on the current hf table and the hathifile
  # to be inserted.

  # By sorting and comparing these dumps we arrive at an "additions" file
  # and a "deletions" file which can be submitted to the Connection class.

  # See exe/hathifiles_database_full for minimal usage example.
  class MonthlyUpdate
    attr_reader :connection, :hathifile, :output_directory, :dumper

    def initialize(connection:, hathifile:, output_directory:)
      @connection = connection
      @hathifile = hathifile.to_s # in case it's a Pathname
      @output_directory = output_directory
      @dumper = Dumper.new(connection)
    end

    # Assembles the additions and deletions files and submits them to the connection
    # for application to the database.
    def run
      connection.update_from_file(additions, deletes_file: deletions)
    end

    # Dumps the current contents of hf table to a file and sorts it.
    # @return [String] path to sorted dump of the current hf database
    def current_dump
      @current_dump ||= File.join(output_directory, "hf_current.txt").tap do |output_file|
        Tempfile.open("hf_current") do |tempfile|
          connection.logger.info "dumping current hf table to #{tempfile.path}"
          dumper.dump_current(output_file: tempfile.path)
          tempfile.flush
          run_system_command "sort #{tempfile.path} > #{output_file}"
        end
      end
    end

    # Dumps a simulated hf table from a hathifile and sorts it.
    # Also dumps the auxiliary tables but we ignore them.
    # @return [String] path to sorted dump based on monthly hathifile
    def new_dump
      @new_dump ||= File.join(output_directory, "hf_new.txt").tap do |output_file|
        connection.logger.info "dumping new database values from #{hathifile} to #{output_directory}"
        dump_file_paths = dumper.dump_from_file(hathifile: hathifile, output_directory: output_directory)
        run_system_command "sort #{dump_file_paths[:hf]} > #{output_file}"
      end
    end

    # Creates .additions file with only the records added or changed in new_dump
    # but not current_dump. This file can be directly loaded by MariaDB.
    # @return [String] path to additions file
    def additions
      @additions ||= hathifile_derivative("additions").tap do |output_file|
        comm_cmd = "comm -13 #{current_dump} #{new_dump} > #{output_file}"
        run_system_command comm_cmd
      end
    end

    # Creates .deletions file with only the records not in new_dump
    # but present in current_dump. This file is a newline-delimited list
    # of HTIDs.
    # @return [String] path to deletions file
    def deletions
      @deletions ||= hathifile_derivative("deletions").tap do |output_file|
        comm_cmd = "bash -c 'comm -23 <(cut -f 1 #{current_dump}) <(cut -f 1 #{new_dump}) > #{output_file}'"
        run_system_command comm_cmd
      end
    end

    private

    # @return [String] path to hathifile derivative with suffix
    def hathifile_derivative(suffix)
      File.join(output_directory, Pathname.new(hathifile).basename.to_s) + "." + suffix
    end

    # Log a shellout and execute it
    def run_system_command(cmd)
      connection.logger.info cmd
      system(cmd, exception: true)
    end
  end
end
