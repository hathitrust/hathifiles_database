RSpec.describe HathifilesDatabase do
  it "has a version number" do
    expect(HathifilesDatabase::VERSION).not_to be nil
  end

  it "can create a connection" do
    expect(HathifilesDatabase.new).to be_a HathifilesDatabase::DB::Connection
  end
end
