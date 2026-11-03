require "sequel"
require "hathifiles_database/constants"

Sequel.extension :migration

# Add indexes after importing data
Sequel.migration do
  up do
    alter_table(HathifilesDatabase::Constants::MAINTABLE) do
      HathifilesDatabase::Constants::MAINTABLE_INDEXES.each do |cols|
        HathifilesDatabase::Constants::LOGGER.info("Adding index #{cols} to main table")
        add_index cols
        HathifilesDatabase::Constants::LOGGER.info("   #{cols} index added.")
      end
    end
    HathifilesDatabase::Constants::LOGGER.info("Done with main table")

    HathifilesDatabase::Constants::FOREIGN_TABLES.values.each do |table|
      alter_table(table) do
        HathifilesDatabase::Constants::LOGGER.info("Adding htid/value index to #{table}")
        add_index [:htid]
        add_index [:value]
        HathifilesDatabase::Constants::LOGGER.info("Done with table #{table}")
      end
    end
  end

  down do
    HathifilesDatabase::Constants::FOREIGN_TABLES.values.each do |table|
      alter_table(table) do
        drop_index [:htid]
        drop_index [:value]
      end
    end

    alter_table(HathifilesDatabase::Constants::MAINTABLE) do
      HathifilesDatabase::Constants::MAINTABLE_INDEXES.each do |cols|
        drop_index cols
      end
    end
  end
end
