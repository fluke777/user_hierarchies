# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "user_hierarchies"

Gem::Specification.new do |s|
  s.name        = "user_hierarchies"
  s.version     = "123"
  s.authors     = ["Tomas Svarovsky"]
  s.email       = ["svarovsky.tomas@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{User hierarchies}
  s.description = %q{User hierarchies}

  s.rubyforge_project = "user_hierarchies"

  s.files         = `git ls-files`.split("\n")
  s.bindir        = 'bin'
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_dependency "fastercsv"
  s.add_dependency "facets"
  s.add_dependency "rforce"
  s.add_dependency "rspec"
  s.add_dependency "jeweler"
  s.add_dependency "rcov"
  
end