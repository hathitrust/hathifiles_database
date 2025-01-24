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

  def line_count(file)
    `wc -l "#{file}"`.strip.split(" ")[0].to_i
  end

  let(:conn) { HathifilesDatabase.new }
  let(:full_hathifile) { data_file_path "hathi_full_20250101.txt.gz" }
  let(:upd_hathifile) { data_file_path "hathi_upd_20250101.txt.gz" }
  let(:delta) { described_class.new(connection: conn, hathifile: full_hathifile, output_directory: @output_directory) }

  describe "#current_dump" do
    it "creates a readable file" do
      expect(File.readable?(delta.current_dump)).to eq(true)
    end

    it "creates a file with the same number of rows as the hf table" do
      expect(line_count(delta.current_dump)).to eq(conn.rawdb[:hf].count)
    end
  end

  describe "#new_dump" do
    it "creates a readable file" do
      expect(File.readable?(delta.new_dump)).to eq(true)
    end

    it "creates a file with the same number of rows as the hathifile" do
      hathifile_line_count = `zcat "#{full_hathifile}" | wc -l`.strip.split(" ")[0].to_i
      expect(line_count(delta.new_dump)).to eq(hathifile_line_count)
    end
  end

  describe "#all_changes" do
    it "creates a readable file" do
      expect(File.readable?(delta.all_changes)).to eq(true)
    end

    it "finds all entries in hathifile" do
      added_lines = File.readlines(delta.all_changes).map(&:chomp)
      expect(added_lines.count).to eq(100)
    end

    it "finds no entries in hathifile if it has already been loaded" do
      conn.update_from_file full_hathifile
      added_lines = File.readlines(delta.all_changes).map(&:chomp)
      expect(added_lines.count).to eq(0)
    end
  end

  describe "#deletions" do
    context "with a full file" do
      it "creates a readable file" do
        expect(File.readable?(delta.deletions)).to eq(true)
      end

      it "finds only test entry not in hathifile" do
        deleted_htids = File.readlines(delta.deletions).map(&:chomp)
        expect(deleted_htids.count).to eq(1)
        expect(deleted_htids[0]).to eq(TEST_HTID)
      end
    end

    context "with an upd file" do
      it "returns nil" do
        upd_delta = described_class.new(connection: conn, hathifile: upd_hathifile, output_directory: @output_directory)
        expect(upd_delta.deletions).to be_nil
      end
    end
  end

  describe "#run" do
    it "runs to completion and writes a log entry" do
      delta.run
      expect(conn.rawdb[:hf_log].count).to eq 1
      expect(conn.rawdb[:hf].count).to eq 100
    end

    it "has no effect when run a second time" do
      delta.run
      new_delta = described_class.new(connection: conn, hathifile: full_hathifile, output_directory: @output_directory)
      new_delta.run
      expected = {additions: 0, all_changes: 0, deletions: 0, hathifile_lines: 100, updates: 0}
      expect(new_delta.statistics).to eq expected
    end

    it "loads only the 10 changed entries between the monthly and update" do
      delta.run
      new_delta = described_class.new(connection: conn, hathifile: upd_hathifile, output_directory: @output_directory)
      new_delta.run
      expected = {additions: 0, all_changes: 10, deletions: 0, hathifile_lines: 100, updates: 10}
      expect(new_delta.statistics).to eq expected
      expect(line_count(new_delta.all_changes)).to eq 10
    end
  end

  describe "#statistics" do
    it "returns a statistics hash with reasonable values" do
      delta.run
      expected = {additions: 100, all_changes: 100, deletions: 1, hathifile_lines: 100, updates: 0}
      expect(delta.statistics).to eq expected
    end
  end
end
