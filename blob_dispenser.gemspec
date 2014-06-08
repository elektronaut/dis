# encoding: utf-8

$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "blob_dispenser/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "blob_dispenser"
  s.version     = BlobDispenser::VERSION
  s.authors     = ["Inge Jørgensen"]
  s.email       = ["inge@elektronaut.no"]
  s.homepage    = "https://github.com/elektronaut/blob_dispenser"
  s.summary     = "Rails engine that stores your data blobs."
  s.description = "BlobDispenser is a Rails engine that takes your uploaded files, de-duplicates them and stores them in layers."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib,spec}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 4.1.1"
  s.add_dependency "fog", "~> 1.22.1"
  #s.add_dependency "activejob"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails", "~> 2.14.2"
  s.add_development_dependency "factory_girl_rails", "~> 4.4.0"
end
