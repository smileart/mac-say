# encoding: utf-8

require 'rubygems'

begin
  require 'bundler/setup'
rescue LoadError => e
  abort e.message
end

require 'rake'


require 'rubygems/tasks'
Gem::Tasks.new

require 'rake/testtask'

Rake::TestTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'yard'
YARD::Rake::YardocTask.new  
task :doc => :yard
