# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib/", __FILE__)
require 'user_hierarchies/version'

Gem::Specification.new do |s|
  s.name        = "user_hierarchies"
  s.version     = GoodData::UserHierarchies::VERSION
  s.authors     = ["Tomas Svarovsky"]
  s.email       = ["svarovsky.tomas@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{User hierarchies}
  s.description = %q{A gem that should help you with inspecting user hierarchies - especially those based on SF model}

  s.rubyforge_project = "user_hierarchies"

  s.files         = `git ls-files`.split("\n")
  s.bindir        = 'bin'
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "activesupport"
  s.add_dependency 'rspec'
  s.add_dependency 'pry'
end