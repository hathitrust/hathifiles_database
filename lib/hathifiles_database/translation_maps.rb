require "yaml"

module HathifilesDatabase
  class TranslationMaps
    MAPPING_TABLES = [:language_codes, :place_of_publication, :bib_fmt]

    def initialize(connection)
      @db = connection.rawdb
    end

    def ensure_tables
      MAPPING_TABLES.each do |table|
        next if @db.table_exists?(table)

        @db.create_table(table, collate: "utf8_general_ci", charset: "utf8") do
          String :code, primary_key: true, fixed: true, size: 3
          String :name
        end

        load_data(table)
      end
    end

    def load_data(table)
      @db.transaction do
        mapping = YAML.load_file(File.dirname(__FILE__) + "/translation_maps/#{table}.yaml")
        @db[table].delete
        mapping.each do |code, name|
          @db[table].insert(code: code, name: name)
        end
      end
    end

    def refresh
      MAPPING_TABLES.each { |t| load_data(t) }
    end
  end
end
