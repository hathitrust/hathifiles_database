require 'sequel'
require 'hathifiles_database/constants'
include HathifilesDatabase::Constants

Sequel.extension :migration

# Add indexes after dropping them for fast data import
Sequel.migration do
  change do
    alter_table(MAINTABLE) do
      add_index [:htid],  unique: true
      MAINTABLE_INDEXES.each do |col|
        add_index [col]
      end
    end

    FOREIGN_TABLES.values.each do |table|
      alter_table(table) do
        add_foreign_key [:htid], MAINTABLE, on_delete: :cascade, name: "#{table}_htid_fk"
      end
    end
  end

end
