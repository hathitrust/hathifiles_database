# frozen_string_literal: true

module HathifilesDatabase
  class DB
    module Writer
      class InfileDatabaseWriter
        attr_accessor :logger, :connection

        # @param [HathifilesDatabase::DB::Connection] connection The database connection
        # @param [Object] dump_file_paths
        def initialize(connection, dump_file_paths, logger: HathifilesDatabase::Constants::LOGGER)
          @connection = connection
          @dump_file_paths = dump_file_paths
          @logger = logger
        end

        def import!
          logger.info "Turn off foreign key checks"
          @connection.mysql_set_foreign_key_checks(:off)
          logger.info "Drop and recreate tables"
          @connection.recreate_tables!
          bulk_load_dump_files
          @logger.info "Add back indexes"
          @connection.add_indexes!
          @logger.info "Turn foreign key checks back on"
          @connection.mysql_set_foreign_key_checks(:on)
        end

        def bulk_load_dump_files
          @dump_file_paths.each_pair do |tablename, filepath|
            logger.info "Loading file #{filepath.basename} into #{tablename}"
            @connection.load_tab_delimited_file(tablename, filepath)
          end
        end
      end

      class TempfileWriter
        attr_accessor :filepaths, :output_files, :maintable_name

        # @param [Hash<Symbol, Pathname>] outputfile_paths, mapping tablename to an outputfile,
        # as returned by TempFileWriter.outputfile_paths_from_linespec
        # @param [Symbol, String] maintable_name The name of the main table (e.g., :hf)
        def initialize(outputfile_paths:, maintable_name:)
          @filepaths = outputfile_paths
          @output_files = @filepaths.each_with_object({}) do |kv, h|
            table, filepath = *kv
            filepath.parent.mkpath
            h[table] = File.open(filepath, "w:utf-8")
          end
          @maintable = @output_files[maintable_name.to_sym]
        end

        def write(line)
          @maintable.puts line.maintable_data.join("\t")
          htid = line.htid
          line.foreign_table_data.each_pair do |tablename, data|
            data.each do |d|
              @output_files[tablename].puts "#{htid}\t#{d}"
            end
          end
        end

        alias_method :<<, :write

        def close
          output_files.values.each { |f| f.close }
        end

        def self.outputfile_paths_from_linespec(linespec, nodate_suffix: false, output_dir: Dir.tmpdir)
          ddir = Pathname.new(output_dir)
          suffix = create_suffix(nodate_suffix)
          linespec.tables.each_with_object({}) do |table, h|
            filename = "#{table}#{suffix}.tsv"
            filepath = ddir + filename
            h[table] = filepath
          end
        end

        def self.create_suffix(nodate_suffix = false)
          if nodate_suffix
            ""
          else
            "_" + DateTime.now.strftime("%Y%m%d_%H%M")
          end
        end

        private_class_method :create_suffix
      end
    end
  end
end
