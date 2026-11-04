require "tmpdir"
require_relative "../lib/hathifiles_database/datafile"

module HathifilesDatabase
  RSpec.describe Datafile do
    let(:txt_datafile_path) { data_file_path "sample_10.txt" }
    let(:gz_datafile_path) { data_file_path "hathi_full_20250101.txt.gz" }
    let(:txt_datafile) { described_class.new(txt_datafile_path, LineSpec.hathifile_linespec) }
    let(:gz_datafile) { described_class.new(gz_datafile_path, LineSpec.hathifile_linespec) }
    let(:all_tables) { [Constants::MAINTABLE] + Constants::FOREIGN_TABLES.values }

    describe "#initialize" do
      it "can create a .txt datafile" do
        expect(txt_datafile).to be_a Datafile
      end

      it "can create a .txt.gz datafile" do
        expect(gz_datafile).to be_a Datafile
      end
    end

    describe "#dump_files_for_data_import" do
      it "writes a file for each table" do
        Dir.mktmpdir do |dir|
          files_written = gz_datafile.dump_files_for_data_import dir
          all_tables.each do |table|
            expect(files_written.key?(table)).to be true
            expect(File.exist?(files_written[table])).to be true
          end
        end
      end
    end
  end
end
