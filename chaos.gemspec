# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chaos/version'

Gem::Specification.new do |spec|
  spec.name          = "chaos"
  spec.version       = Chaos::VERSION
  spec.authors       = ["Etienne Garnier"]
  spec.email         = ["garnier.etienne@gmail.com"]
  spec.description   = %q{Bootstrap server and deploy application using heroku buildpacks}
  spec.summary       = %q{Bootstrap and configure services on individual server. Can also configure your app to deploy to freshly bootstrapped server using git.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
