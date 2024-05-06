# frozen_string_literal: true

require "zlib"
require_relative "linespec"
require "hathifiles_database/db/writer"
require "delegate"

module HathifilesDatabase
  class Datafile < SimpleDelegator
    include Enumerable

    # Open a hathifile, not caring whether or not it's
    # gzipped
    # @param [String, Pathname] path Path to the file
    # @param [HathifilesDatabase::LineSpec] linespec to use
    def initialize(path, linespec = LineSpec.default_linespec)
      @io = open_regardless_of_gzip(path)
      __setobj__(@io)
      @linespec = linespec
    end

    # @param [String, Pathname] path Path to the file
    # @return [IO]
    def open_regardless_of_gzip(path)
      path = Pathname.new(path)
      raise Errno::ENOENT.new(path.to_s) unless path.exist?
      Zlib::GzipReader.open(path.to_s)
    rescue Zlib::GzipFile::Error
      File.open(path.to_s)
    end

    # Yield the lines. Log an error if something doesn't parse right.
    # @yieldreturn HathifilesDatabase::Line
    # @return [void]
    def each
      return enum_for(:each) unless block_given?

      @io.each_with_index do |rawline, index|
        l = @linespec.parse(rawline)
        yield l unless l.empty?
      rescue Exception::WrongNumberOfColumns => e
        Services[:logger].error e
      end
    end

    # We need a way to dump tab-delimited files so they
    # can be loaded with LOAD DATA INFILE -- doing normal
    # loads with a full file takes days.
    # @param [String, Pathname] destination_dir Where the files will be dumped
    # @return [Hash<Symbol, Pathname>] Mapping of tables names to the filepaths to import
    def dump_files_for_data_import(destination_dir, nodate_suffix: false)
      w_class = HathifilesDatabase::DB::Writer::TempfileWriter
      filepaths = w_class.outputfile_paths_from_linespec(@linespec, output_dir: destination_dir, nodate_suffix: nodate_suffix)
      writer = w_class.new(outputfile_paths: filepaths, maintable_name: @linespec.maintable_name)
      line_number = 1
      each do |line|
        Services[:logger].info "#{line_number} lines processed" if line_number % 500_000 == 0
        writer << line
        line_number += 1
      end
      writer.close
      Services[:logger].info ""
      filepaths
    end
  end
end
