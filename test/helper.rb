require 'rubygems'

require 'coveralls'
Coveralls.wear!

begin
  require 'bundler/setup'
rescue LoadError => error
  abort error.message
end

require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require "minitest/reporters"

Minitest::Reporters.use! [
  Minitest::Reporters::SpecReporter.new
]
