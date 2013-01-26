$:.push File.expand_path("../lib", __FILE__)
require 'pants/version'


Gem::Specification.new do |s| 
  s.name =          "pants"
  s.version =       Pants::VERSION
  s.author =        %q(Steve Loveless)
  s.homepage =      %q(http://github.com/turboladen/pants)
  s.email =         %q(steve.loveless@gmail.com)
  s.summary =       %q(Easy, fast, I/O multiplexer)
  s.description =   %q[Pants redirects IO using EventMachine from one input source
to many different destinations. In some senses, pants is like a *nix pipe that
(works on Windows and) allows for duplicating data across many pipes (like
splice and tee).]

  s.required_rubygems_version = ">=1.8.0"
  s.files =         `git ls-files`.split($/)
  s.test_files =    s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = %w(lib)
  s.executables =   %w(pants)

  s.add_dependency "eventmachine", ">= 1.0.0"
  s.add_dependency "log_switch", ">= 0.4.0"
  s.add_dependency "thor"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", ">= 2.6.0"
  s.add_development_dependency "simplecov", ">= 0"
  s.add_development_dependency "yard", ">= 0.7.2"
end
