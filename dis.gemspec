# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "dis/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "dis"
  s.version     = Dis::VERSION
  s.authors     = ["Inge Jørgensen"]
  s.email       = ["inge@elektronaut.no"]
  s.homepage    = "https://github.com/elektronaut/dis"
  s.summary     = "A file store for your Rails app"
  s.description = "Dis is a Rails plugin that stores your file uploads and " \
                  "other binary blobs."
  s.license     = "MIT"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "README.md"]

  s.required_ruby_version = ">= 2.7.0"

  s.add_dependency "fog-core", "~> 2.1.2"
  s.add_dependency "fog-local"
  s.add_dependency "pmap", "~> 1.1.0"
  s.add_dependency "rails", "> 5.0"

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "simplecov", "~> 0.17.1"
  s.add_development_dependency "sqlite3"
  s.metadata = {
    "rubygems_mfa_required" => "true"
  }
end
