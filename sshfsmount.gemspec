# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sshfsmount/version"

Gem::Specification.new do |spec|
  spec.name          = "sshfsmount"
  spec.version       = Sshfsmount::VERSION
  spec.authors       = ["Tim Bellefleur"]
  spec.email         = ["nomoon@phoebus.ca"]

  spec.summary       = "A simple front-end CLI to SSHFS"
  spec.homepage      = "https://github.com/nomoon/sshfsmount"
  spec.license       = "MIT"
  spec.required_ruby_version = "~> 2.2"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|Gemfile\.lock|\.)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rubocop", "~> 0.49"
  spec.add_development_dependency "coveralls", "~> 0.8"

  spec.add_runtime_dependency "gli", "~> 2.16"
  spec.add_runtime_dependency "json", "~> 2.0"
end
