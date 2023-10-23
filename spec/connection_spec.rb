require_relative "../lib/hathifiles_database/db/connection"

RSpec.describe HathifilesDatabase::DB::Connection do
  let(:conn) { described_class.new(ENV["HATHIFILES_MYSQL_CONNECTION"]) }

  describe "#initialize" do
    it "can create a connection" do
      expect(conn).to be_a HathifilesDatabase::DB::Connection
    end
  end

  describe "#recreate_tables!" do
    it "does not raise an exception" do
      conn.recreate_tables!
      expect(conn.rawdb.table_exists?(HathifilesDatabase::Constants::MAINTABLE)).to be true
      HathifilesDatabase::Constants::FOREIGN_TABLES.each do |_k, table|
        expect(conn.rawdb.table_exists?(table)).to be true
      end
    end
  end
end
