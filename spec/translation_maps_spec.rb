# frozen_string_literal: true

require_relative "../lib/hathifiles_database/translation_maps"

RSpec.describe HathifilesDatabase::TranslationMaps do
  let(:conn) { HathifilesDatabase.new }
  let(:db) { conn.rawdb }
  let(:tmaps) { described_class.new(conn) }
  let(:tables) { [:language_codes, :place_of_publication, :bib_fmt] }

  # precondition for each test: tables don't exist
  before(:each) do
    tables.each { |t| db.drop_table?(t) }
  end

  describe "#ensure_tables" do
    it "creates tables if they don't exist" do
      tmaps.ensure_tables

      tables.each { |t| expect(db.table_exists?(t)).to be true }
    end

    it "doesn't change data in existing tables" do
      # load data, then mess with it
      tmaps.ensure_tables
      db[:bib_fmt].insert(code: "ZZ", name: "test")
      db[:bib_fmt].where(code: "BK").update(name: "TestThing")

      tmaps.ensure_tables

      # messed data should still be there
      expect(db[:bib_fmt].where(code: "BK").first[:name]).to eq("TestThing")
      expect(db[:bib_fmt].where(code: "ZZ").first[:name]).to eq("test")
    end
  end

  describe "#refresh" do
    it "doesn't create tables" do
      expect { tmaps.refresh }.to raise_exception(Sequel::DatabaseError, /Table.*doesn't exist/)
    end

    it "reloads data" do
      # load data, then mess with it
      tmaps.ensure_tables
      db[:language_codes].delete
      db[:bib_fmt].where(code: "BK").update(name: "TestThing")

      tmaps.refresh

      # data has been reset
      expect(db[:language_codes].first).not_to be_nil
      expect(db[:bib_fmt].where(code: "BK").first[:name]).to eq("Book")
    end
  end
end
