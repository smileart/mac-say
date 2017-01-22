require 'rubygems'

begin
  require 'bundler/setup'
rescue LoadError => error
  abort error.message
end

require 'minitest/autorun'
