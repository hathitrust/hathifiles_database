require_relative "../lib/hathifiles_database/db/connection"

RSpec.describe HathifilesDatabase::Exception do
  describe HathifilesDatabase::Exception::WrongNumberOfColumns do
    let(:test_params) { {htid: "test.001", count: 22, expected: 33} }

    describe "#initialize" do
      it "creates a WrongNumberOfColumns object" do
        expect(described_class.new(**test_params)).to be_a HathifilesDatabase::Exception::WrongNumberOfColumns
      end
    end

    describe "#to_s" do
      it "includes the htid, expected, and count values" do
        @exc = described_class.new(**test_params)
        # HathifilesDatabase::Exception::WrongNumberOfColumns htid = test.001 has 22 items (expected 33)
        expect(@exc.to_s).to match "test.001"
      end
    end
  end
end
