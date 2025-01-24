# frozen_string_literal: true

RSpec.describe HathifilesDatabase::Log do
  around(:example) do |ex|
    conn.rawdb[:hf_log].delete
    ex.run
    conn.rawdb[:hf_log].delete
  end

  let(:conn) { HathifilesDatabase.new }
  let(:log) { described_class.new(connection: conn) }

  describe ".new" do
    it "creates a log object" do
      expect(log).to be_a HathifilesDatabase::Log
    end
  end

  describe "#add" do
    it "adds one entry" do
      log.add(hathifile: "hathi_upd_20240101.txt.gz")
      expect(conn.rawdb[:hf_log].count).to eq 1
    end

    it "updates instead of duplicating" do
      log.add(hathifile: "hathi_upd_20240101.txt.gz")
      log.add(hathifile: "hathi_upd_20240101.txt.gz")
      expect(conn.rawdb[:hf_log].count).to eq 1
    end
  end

  describe "#exist?" do
    it "returns `true` if log entry exists" do
      log.add(hathifile: "hathi_full_20231231.txt.gz")
      expect(log.exist?(hathifile: "hathi_full_20231231.txt.gz")).to eq true
    end

    it "returns `false` if log entry does not exist (empty table)" do
      expect(log.exist?(hathifile: "hathi_full_00000000.txt.gz")).to eq false
    end

    it "returns `false` if log entry does not exist (nonempty table)" do
      log.add(hathifile: "hathi_full_20231231.txt.gz")
      expect(log.exist?(hathifile: "hathi_full_00000000.txt.gz")).to eq false
    end
  end

  describe "#all_of_type" do
    it "returns all full files" do
      log.add(hathifile: "hathi_full_20231231.txt.gz")
      log.add(hathifile: "hathi_upd_20240101.txt.gz")
      log.add(hathifile: "hathi_upd_20240102.txt.gz")
      log.add(hathifile: "hathi_upd_20240103.txt.gz")
      log.add(hathifile: "hathi_upd_20240104.txt.gz")
      log.add(hathifile: "hathi_upd_20240105.txt.gz")
      expect(log.all_of_type(type: "full").count).to eq 1
    end

    it "returns all upd files" do
      log.add(hathifile: "hathi_full_20231231.txt.gz")
      log.add(hathifile: "hathi_upd_20240101.txt.gz")
      log.add(hathifile: "hathi_upd_20240102.txt.gz")
      log.add(hathifile: "hathi_upd_20240103.txt.gz")
      log.add(hathifile: "hathi_upd_20240104.txt.gz")
      log.add(hathifile: "hathi_upd_20240105.txt.gz")
      expect(log.all_of_type(type: "upd").count).to eq 5
    end

    it "raises on unknown type" do
      expect { log.all_of_type(type: "shwoozle") }.to raise_error(StandardError)
    end
  end
end
