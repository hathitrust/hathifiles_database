require "sequel"
require "hathifiles_database/constants"

Sequel.extension :migration

# Do nothing. Migration 100 is our "tables created, no indexes" version
Sequel.migration do
  up do
  end
end
