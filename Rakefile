# -*- ruby -*-

require 'rubygems'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'

YARD::Rake::YardocTask.new do |t|
  t.files = %w(lib/**/*.rb - History.rdoc)
  t.options = %w(--title pants Documentation (#{Pants::VERSION}))
  t.options += %w(--main README.rdoc)
end

RSpec::Core::RakeTask.new do |t|
  t.ruby_opts = %w(-w)
end

# Alias for rubygems-test
task :test => :spec

task :default => :test

# vim: syntax=ruby
