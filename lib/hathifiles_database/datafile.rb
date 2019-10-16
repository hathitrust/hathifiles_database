# frozen_string_literal: true

require 'zlib'
require_relative 'linespec'

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
      Zlib::GzipReader.open(path.to_s)
    rescue Zlib::GzipFile::Error
      File.open(path.to_s)
    end

    # @yieldreturn HathifilesDatabase::Line
    # @return [void]
    def each
      return enum_for(:each) unless block_given?

      @io.each do |rawline|
        yield @linespec.parse(rawline)
      end
    end

    # We need a way to dump tab-delimited files so they
    # can be loaded with LOAD DATA INFILE -- doing normal
    # loads with a full file takes days.
    # @param [String, Pathname] destination_dir Where the files will be dumped
    # @return [void]
    def dump_files_for_data_import(destination_dir, plain_names: false)
      ddir = Pathname.new(destination_dir).realdirpath
      ddir.mkpath
      suffix      = if plain_names
                      'tst'
                    else
                      DateTime.now.strftime('%Y%m%d_%H%M')
                    end
      output_file = @linespec.tables.each_with_object({}) do |t, h|
        filename = "#{t}_#{suffix}.tsv"
        filepath = ddir + filename
        h[t]     = File.open(filepath, 'w:utf-8')
      end

      maintable = output_file[@linespec.maintable_name]

      self.each do |line|
        maintable.puts line.maintable_data.join("\t")
        line.foreign_table_data.each_pair do |tablename, data|
          htid = line.htid
          data.each do |d|
            output_file[tablename].puts "#{htid}\t#{d}"
          end
        end
      end

      output_file.values.each { |f| f.close }


    end

  end
end
