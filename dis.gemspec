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

  s.required_ruby_version = ">= 3.2.0"

  s.add_dependency "benchmark"
  s.add_dependency "concurrent-ruby", ">= 1.1"
  s.add_dependency "fog-core", ">= 2.1.2", "< 2.7.0"
  s.add_dependency "fog-local"
  s.add_dependency "rails", ">= 7.1"
  s.add_dependency "ruby-progressbar", "~> 1.11"

  s.metadata = {
    "rubygems_mfa_required" => "true"
  }
end
