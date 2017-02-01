# frozen_string_literal: true
require 'rubygems'

require 'coveralls'
Coveralls.wear!

require 'simplecov'
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start

begin
  require 'bundler/setup'
rescue LoadError => error
  abort error.message
end

require 'minitest/autorun'
require 'minitest/reporters'

Minitest::Reporters.use! [
  Minitest::Reporters::SpecReporter.new
]
