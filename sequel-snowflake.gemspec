# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sequel-snowflake/version'

Gem::Specification.new do |spec|
  spec.name          = "sequel-snowflake"
  spec.version       = Sequel::Snowflake::VERSION
  spec.authors       = ["Yesware, Inc"]
  spec.email         = ["engineering@yesware.com"]
  spec.license       = ["MIT"]
  spec.summary       = %q{Sequel adapter for Snowflake}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/Yesware/sequel-snowflake"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]


  spec.add_runtime_dependency 'sequel'
  spec.add_runtime_dependency 'ruby-odbc'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
end
