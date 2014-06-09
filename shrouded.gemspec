# encoding: utf-8

$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "shrouded/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "shrouded"
  s.version     = Shrouded::VERSION
  s.authors     = ["Inge Jørgensen"]
  s.email       = ["inge@elektronaut.no"]
  s.homepage    = "https://github.com/elektronaut/shrouded"
  s.summary     = "Rails engine that stores your data blobs."
  s.description = "Shrouded is a Rails engine that takes your uploaded files, de-duplicates them and stores them in layers."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib,spec}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.required_ruby_version = '>= 1.9.2'

  s.add_dependency "rails", "~> 4.1.0"
  s.add_dependency "fog", "~> 1.22.1"
  s.add_dependency "activejob"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails", "~> 3.0.0"
end
