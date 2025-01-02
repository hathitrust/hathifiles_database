# frozen_string_literal: true

require "tmpdir"

TEST_HTID = "test.001"

RSpec.describe HathifilesDatabase::DeltaUpdate do
  around(:example) do |ex|
    HathifilesDatabase::Constants::ALL_TABLES.each do |table|
      conn.rawdb[table].delete
    end
    conn.rawdb[:hf].insert(htid: TEST_HTID)
    Dir.mktmpdir do |dir|
      @output_directory = dir
      ex.run
    end
  end

  def word_count(file)
    `wc -l "#{file}"`.strip.split(" ")[0].to_i
  end

  let(:conn) { HathifilesDatabase.new(ENV["HATHIFILES_MYSQL_CONNECTION"]) }
  let(:hathifile) { data_file_path "sample_100.txt.gz" }
  let(:monthly) { described_class.new(connection: conn, hathifile: hathifile, output_directory: @output_directory) }

  describe "#current_dump" do
    it "creates a readable file" do
      expect(File.readable?(monthly.current_dump)).to eq(true)
    end

    it "creates a file with the same number of rows as the hf table" do
      expect(word_count(monthly.current_dump)).to eq(conn.rawdb[:hf].count)
    end
  end

  describe "#new_dump" do
    it "creates a readable file" do
      expect(File.readable?(monthly.new_dump)).to eq(true)
    end

    it "creates a file with the same number of rows as the hf table" do
      hathifile_line_count = `zcat "#{hathifile}" | wc -l`.strip.split(" ")[0].to_i
      expect(word_count(monthly.new_dump)).to eq(hathifile_line_count)
    end
  end

  describe "#additions" do
    it "creates a readable file" do
      expect(File.readable?(monthly.additions)).to eq(true)
    end

    it "finds all entries in hathifile" do
      added_lines = File.readlines(monthly.additions).map(&:chomp)
      expect(added_lines.count).to eq(100)
    end

    it "finds no entries in hathifile if it has already been loaded" do
      conn.update_from_file hathifile
      added_lines = File.readlines(monthly.additions).map(&:chomp)
      expect(added_lines.count).to eq(0)
    end
  end

  describe "#deletions" do
    it "creates a readable file" do
      expect(File.readable?(monthly.deletions)).to eq(true)
    end

    it "finds only test entry not in hathifile" do
      deleted_htids = File.readlines(monthly.deletions).map(&:chomp)
      expect(deleted_htids.count).to eq(1)
      expect(deleted_htids[0]).to eq(TEST_HTID)
    end
  end

  describe "#run" do
    it "runs to completion and writes a log entry" do
      conn.rawdb.transaction do
        monthly.run
        expect(conn.rawdb[:hf_log].count).to eq 1
        raise Sequel::Rollback
      end
    end
  end

  describe "#statistics" do
    it "returns a statistics hash with reasonable values" do
      conn.rawdb.transaction do
        monthly.run
        expected = {additions_lines: 100, deletions_lines: 1, hathifile_lines: 100}
        expect(monthly.statistics).to eq expected
        raise Sequel::Rollback
      end
    end
  end
end
