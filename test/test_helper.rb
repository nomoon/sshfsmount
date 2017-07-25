# frozen_string_literal: true

require "simplecov"
require "coveralls"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter,
]
SimpleCov.start

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "sshfsmount"

require "minitest/autorun"
