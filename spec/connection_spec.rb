require_relative "../lib/hathifiles_database/db/connection"
require_relative "../lib/hathifiles_database/constants"

RSpec.describe HathifilesDatabase::DB::Connection do
  let(:conn) { described_class.new }
  let(:txt_datafile_path) { data_file_path "sample_10.txt" }
  let(:gz_datafile_path) { data_file_path "hathi_full_20250101.txt.gz" }

  before(:all) do
    described_class.new.recreate_tables!
  end

  before(:each) do
    HathifilesDatabase::Constants::ALL_TABLES.each do |table|
      conn.rawdb[table].delete
    end
  end

  describe "#initialize" do
    it "can create a connection" do
      expect(conn).to be_a HathifilesDatabase::DB::Connection
    end
  end

  describe "#recreate_tables!" do
    it "recreates all tables" do
      conn.recreate_tables!
      HathifilesDatabase::Constants::ALL_TABLES.each do |table|
        expect(conn.rawdb.table_exists?(table)).to be true
      end
    end
  end

  describe "#update_from_file" do
    context "with .txt" do
      it "writes 10 records" do
        conn.update_from_file(txt_datafile_path)
        expect(conn.rawdb[:hf].count).to eq(10)
        expect(conn.rawdb[:hf_log].count).to eq(1)
      end
    end

    context "with .txt.gz" do
      it "writes 100 records" do
        conn.update_from_file(gz_datafile_path)
        expect(conn.rawdb[:hf].count).to eq(100)
        expect(conn.rawdb[:hf_log].count).to eq(1)
      end
    end

    context "with callback" do
      it "invokes callback for 10 inserted records" do
        @total_records_inserted = 0
        conn.update_from_file(txt_datafile_path) do |records_inserted|
          @total_records_inserted += records_inserted
        end
        expect(@total_records_inserted).to eq(10)
      end
    end
  end

  describe "#load_tab_delimited_file" do
    it "loads 10 records" do
      conn.load_tab_delimited_file(:hf, txt_datafile_path)
      expect(conn.rawdb[:hf].count).to eq(10)
      expect(conn.rawdb[:hf_log].count).to eq(1)
    end
  end

  describe "#start_from_scratch" do
    it "returns a Hash of tempfiles" do
      tempfiles = conn.start_from_scratch(txt_datafile_path)
      tempfiles.values.each do |tempfile|
        expect(File.readable?(tempfile)).to be true
      end
      expect(conn.rawdb[:hf_log].count).to eq(1)
    end
  end
end
