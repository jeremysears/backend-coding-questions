# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lookout/backend_coding_1/version'

Gem::Specification.new do |spec|
  spec.name          = "lookout-backend_coding_1"
  spec.version       = Lookout::BackendCoding1::VERSION
  spec.authors       = ["Lookout, Inc"]
  spec.email         = ["jobs@lookout.com"]
  spec.summary       = %q{Coding question for Backend Engineering at Lookout.}
  spec.description   = %q{Coding question #1 for Backend Engineering positions at Lookout.}
  spec.homepage      = "https://github.com/lookout/lookout-backend_coding_1"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_protobuf"
  spec.add_dependency "rest_client"
  spec.add_dependency "forgery"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
