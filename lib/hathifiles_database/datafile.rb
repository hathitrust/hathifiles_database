# frozen_string_literal: true

require 'zlib'
require_relative 'linespec'

module HathifilesDatabase
  class Datafile < SimpleDelegator
    include Enumerable

    # Open a hathifile, not caring whether or not it's
    # gzipped
    # @param [String, Pathname] path Path to the file
    def initialize(path, linespec=LineSpec.new)
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

  end
end
