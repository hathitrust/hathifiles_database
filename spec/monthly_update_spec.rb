# frozen_string_literal: true

require "tmpdir"
require_relative "../lib/hathifiles_database/monthly_update"

TEST_HTID = "test.001"

RSpec.describe HathifilesDatabase::MonthlyUpdate do
  around(:example) do |ex|
    conn.rawdb[:hf].insert(htid: TEST_HTID)
    Dir.mktmpdir do |dir|
      @output_directory = dir
      ex.run
    end
    conn.rawdb[:hf].where(htid: TEST_HTID).delete
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
    it "runs to completion" do
      save_slice_size = conn.slice_size
      conn.slice_size = 1
      save_log_report_chunk_size = conn.log_report_chunk_size
      conn.log_report_chunk_size = 1
      conn.rawdb.transaction do
        monthly.run
        raise Sequel::Rollback
      end
      conn.slice_size = save_slice_size
      conn.log_report_chunk_size = save_log_report_chunk_size
    end
  end
end
