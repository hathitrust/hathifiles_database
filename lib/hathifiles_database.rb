# frozen_string_literal: true

require "hathifiles_database/version"
require "hathifiles_database/datafile"
require "hathifiles_database/delta_update"
require "hathifiles_database/db/connection"
require "hathifiles_database/hathifiles"
require "hathifiles_database/log"

module HathifilesDatabase
  def self.new(...)
    HathifilesDatabase::DB::Connection.new(...)
  end
end
