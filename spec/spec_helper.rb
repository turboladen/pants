require 'simplecov'

SimpleCov.start

$:.unshift(File.dirname(__FILE__) + '/../lib')
Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each { |f| require f }

require 'pants'
Pants.log = true

