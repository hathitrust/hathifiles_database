# frozen_string_literal: true

require "hathifiles_database/version"
require "hathifiles_database/datafile"
require "hathifiles_database/db/connection"

module HathifilesDatabase
  def self.new(connection_string)
    HathifilesDatabase::DB::Connection.new(connection_string)
  end
end
