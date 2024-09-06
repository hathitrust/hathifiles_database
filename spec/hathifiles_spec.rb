# frozen_string_literal: true

require "tmpdir"

RSpec.describe HathifilesDatabase::Hathifiles do
  around(:example) do |ex|
    conn.rawdb[:hf_log].delete
    Dir.mktmpdir do |dir|
      @output_directory = dir
      setup_example
      ex.run
    end
    conn.rawdb[:hf_log].delete
  end

  let(:conn) { HathifilesDatabase.new(ENV["HATHIFILES_MYSQL_CONNECTION"]) }
  let(:log) { HathifilesDatabase::Log.new(connection: conn) }
  let(:hathifiles) { described_class.new(hathifiles_directory: @output_directory, connection: conn) }

  def setup_example
    system "touch #{File.join(@output_directory, "hathi_full_20231031.txt.gz")}"
    system "touch #{File.join(@output_directory, "hathi_full_20231130.txt.gz")}"
    system "touch #{File.join(@output_directory, "hathi_full_20231231.txt.gz")}"
    system "touch #{File.join(@output_directory, "hathi_full_20240131.txt.gz")}"
    system "touch #{File.join(@output_directory, "hathi_upd_20240131.txt.gz")}"
    system "touch #{File.join(@output_directory, "hathi_upd_20240201.txt.gz")}"
    system "touch #{File.join(@output_directory, "hathi_upd_20240202.txt.gz")}"
    system "touch #{File.join(@output_directory, "bogus_hathi_upd_20240203.txt.gz")}"
    system "touch #{File.join(@output_directory, "hathi_upd_20240204.jpeg")}"
  end

  describe ".new" do
    it "creates a hathifiles object" do
      expect(hathifiles).to be_a HathifilesDatabase::Hathifiles
    end
  end

  describe ".missing_full_hathifiles" do
    it "reports the most recent full hathifile" do
      expect(hathifiles.missing_full_hathifiles[0]).to eq "hathi_full_20240131.txt.gz"
    end

    it "reports nothing for most recent full hathifile if in database" do
      log.add(hathifile: "hathi_full_20240131.txt.gz")
      expect(hathifiles.missing_full_hathifiles).to eq []
    end
  end

  describe ".missing_update_hathifiles" do
    context "with unlogged full hathifile" do
      context "with unlogged updates" do
        it "reports unlogged updates" do
          expect(hathifiles.missing_update_hathifiles).to eq ["hathi_upd_20240131.txt.gz", "hathi_upd_20240201.txt.gz", "hathi_upd_20240202.txt.gz"]
        end
      end

      context "with logged update" do
        it "reports all updates" do
          log.add(hathifile: "hathi_upd_20240201.txt.gz")
          expect(hathifiles.missing_update_hathifiles).to eq ["hathi_upd_20240131.txt.gz", "hathi_upd_20240201.txt.gz", "hathi_upd_20240202.txt.gz"]
        end
      end
    end

    context "with logged full hathifile" do
      context "with unlogged updates" do
        it "reports the unlogged updates" do
          log.add(hathifile: "hathi_full_20240131.txt.gz")
          expect(hathifiles.missing_update_hathifiles).to eq ["hathi_upd_20240131.txt.gz", "hathi_upd_20240201.txt.gz", "hathi_upd_20240202.txt.gz"]
        end
      end

      context "with logged update" do
        it "reports only the unlogged updates" do
          log.add(hathifile: "hathi_full_20240131.txt.gz")
          log.add(hathifile: "hathi_upd_20240201.txt.gz")
          expect(hathifiles.missing_update_hathifiles).to eq ["hathi_upd_20240131.txt.gz", "hathi_upd_20240202.txt.gz"]
        end
      end
    end
  end
end
