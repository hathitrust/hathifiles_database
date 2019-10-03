require "bundler/setup"
require "hathifiles_database"
require 'pathname'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

SPEC_DATA_DIR = Pathname.new(__dir__).realdirpath + "data"

# Verify that a file exists in the spec/data dir and return its path
# @param [String] relative_path The relative_path within spec/data
def data_file_path(relative_path)
  path = SPEC_DATA_DIR + relative_path
  raise "File #{relative_path} not found under #{SPEC_DATA_DIR}" unless File.exist?(path)

  path
end

