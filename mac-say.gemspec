# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mac/say/version'

Gem::Specification.new do |gem|
  gem.name          = "mac-say"
  gem.version       = Mac::Say::VERSION
  gem.summary       = %q{Ruby wrapper around the macOS `say` command}
  gem.description   = %q{Ruby wrapper around the modern version of the macOS `say` command. Inspired by the @bratta's mactts}
  gem.license       = "MIT"
  gem.authors       = ["Serge Bedzhyk"]
  gem.email         = "smileart21@gmail.com"
  gem.homepage      = "https://rubygems.org/gems/mac-say"

  gem.files         = `git ls-files`.split($/)

  `git submodule --quiet foreach --recursive pwd`.split($/).each do |submodule|
    submodule.sub!("#{Dir.pwd}/",'')

    Dir.chdir(submodule) do
      `git ls-files`.split($/).map do |subpath|
        gem.files << File.join(submodule,subpath)
      end
    end
  end
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_development_dependency 'bundler', '~> 1.10'
  gem.add_development_dependency 'minitest', '~> 5.0'
  gem.add_development_dependency 'minitest-reporters', '~> 1.1'
  gem.add_development_dependency 'rake', '~> 12.0'
  gem.add_development_dependency 'simplecov', '~> 0.12'
  gem.add_development_dependency 'rubygems-tasks', '~> 0.2'
  gem.add_development_dependency 'yard', '~> 0.8.7.5'
  gem.add_development_dependency 'inch', '~> 0.7.1'
  gem.add_development_dependency 'redcarpet', '~> 3.4'
  gem.add_development_dependency 'github-markup', '~> 1.4'
  gem.add_development_dependency 'm', '~> 1.5'
  gem.add_development_dependency 'coveralls', '~> 0.8'
end
