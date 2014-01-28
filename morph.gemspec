# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'morph/version'

Gem::Specification.new do |spec|
  spec.name          = "morph"
  spec.version       = Morph::VERSION
  spec.authors       = ["Matthew Landauer"]
  spec.email         = ["matthew@oaf.org.au"]
  spec.description   = %q{Command line interface for Morph}
  spec.summary       = %q{Command line interface for Morph}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "thor"
  spec.add_dependency "excon"
  spec.add_dependency 'archive-tar-minitar'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.executables   = %w(morph)
end
