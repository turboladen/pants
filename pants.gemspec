$:.push File.expand_path("../lib", __FILE__)
require 'pants/version'

Gem::Specification.new do |s| 
  s.name = "pants"
  s.version = Pants::VERSION
  s.author = %q(Steve Loveless)
  s.homepage = %q(http://github.com/turboladen/pants)
  s.email = %q(steve.loveless@gmail.com)
  s.summary = %q(FIX)
  s.description = %q(FIX)

  s.required_rubygems_version = ">=1.8.0"
  s.files = Dir.glob("{lib,spec}/**/*") + Dir.glob("*.rdoc") +
    %w(.gemtest Gemfile pants.gemspec Rakefile)
  s.test_files = Dir.glob("{spec}/**/*")
  s.require_paths = ["lib"]

  s.add_dependency "log_switch", ">= 0.4.0"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", ">= 2.6.0"
  s.add_development_dependency "simplecov", ">= 0" if RUBY_VERSION > '1.9'
  s.add_development_dependency "yard", ">= 0.7.2"
end
