lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hathifiles_database/version"

Gem::Specification.new do |spec|
  spec.name = "hathifiles_database"
  spec.version = HathifilesDatabase::VERSION
  spec.authors = ["Bill Dueber"]
  spec.email = ["bill@dueber.com"]

  spec.summary = %q{Keep a database of the data in the hathifiles}
  spec.homepage = "https://github.com/billdueber/hathifiles_database"
  spec.license = "MIT"

  spec.metadata["allowed_push_host"] = "http://gems.www.lib.umich.edu"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage + '/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "yard"


  spec.add_dependency 'dotenv'
  spec.add_dependency 'ettin' # config
  spec.add_dependency 'library_stdnums' # normalize
  spec.add_dependency 'sequel'
  spec.add_dependency 'thor' # command line


end
