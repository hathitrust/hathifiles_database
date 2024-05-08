# frozen_string_literal: true

require "hathifiles_database/dumper"

module HathifilesDatabase
  class MonthlyUpdate
    attr_reader :connection, :hathifile, :output_directory, :dumper

    def initialize(connection:, hathifile:, output_directory:)
      @connection = connection
      @hathifile = hathifile.to_s # in case it's a Pathname
      @output_directory = output_directory
      @dumper = Dumper.new(connection)
    end

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

    # @return [String] path to sorted dump based on monthly hathifile
    def new_dump
      @new_dump ||= File.join(output_directory, "hf_new.txt").tap do |output_file|
        connection.logger.info "dumping new database values from #{hathifile} to #{output_directory}"
        dump_file_paths = dumper.dump_from_file(hathifile: hathifile, output_directory: output_directory)
        run_system_command "sort #{dump_file_paths[:hf]} > #{output_file}"
      end
    end

    # @return [String] path to the hathifile minus unchanged records
    def additions
      @additions ||= hatifile_derivative("additions").tap do |output_file|
        comm_cmd = "comm -13 #{current_dump} #{new_dump} > #{output_file}"
        run_system_command comm_cmd
      end
    end

    # @return [String] path to the monthly hathifile dump minus unchanged records
    def deletions
      @deletions ||= hatifile_derivative("deletions").tap do |output_file|
        comm_cmd = "bash -c 'comm -23 <(cut -f 1 #{current_dump}) <(cut -f 1 #{new_dump}) > #{output_file}'"
        run_system_command comm_cmd
      end
    end

    private

    def hatifile_derivative(suffix)
      File.join(output_directory, Pathname.new(hathifile).basename.to_s) + "." + suffix
    end

    def run_system_command(cmd)
      connection.logger.info cmd
      system(cmd, exception: true)
    end
  end
end
