require 'sequel'
require 'hathifiles_database/constants'
include HathifilesDatabase::Constants

Sequel.extension :migration

# Add indexes after importing data
Sequel.migration do
  up do
    alter_table(MAINTABLE) do
      MAINTABLE_INDEXES.each do |col|
        HathifilesDatabase::Constants::LOGGER.info("Adding index #{col} to main table")
        add_index [col]
        HathifilesDatabase::Constants::LOGGER.info("   #{col} index added.")
      end
    end
    HathifilesDatabase::Constants::LOGGER.info("Done with main table")

    FOREIGN_TABLES.values.each do |table|
      alter_table(table) do
        HathifilesDatabase::Constants::LOGGER.info("Adding htid/value index to #{table}")        
        add_index [:htid]
        add_index [:value]
        HathifilesDatabase::Constants::LOGGER.info("Done with table #{table}")        
      end
    end
  end

  down do
    FOREIGN_TABLES.values.each do |table|
      alter_table(table) do
        drop_index [:htid]
        drop_index [:value]
      end
    end

    alter_table(MAINTABLE) do
      MAINTABLE_INDEXES.each do |col|
        drop_index [col]
      end
    end

  end

end
