
$:.push File.expand_path("../lib", __FILE__)
require "rubactive/version"

Gem::Specification.new do |s|
  s.name = "rubactive"
  s.homepage = "http://github.com/marick/rubactive"
  s.license = "MIT"
  s.summary = %Q{A basic and perhaps misinformed library for  learning about reactive programming}
  s.description = %Q{A basic and perhaps misinformed library for learning about reactive programming}
  s.email = "marick@exampler.com"
  s.authors = ["Brian Marick"]
  s.required_ruby_version = '>= 1.9.2'
  s.version = Rubactive::VERSION

  s.rubyforge_project = "rubactive"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "shoulda", ">= 0"
  s.add_development_dependency "assert2"
  s.add_development_dependency "rr"
  s.add_development_dependency "bundler", "~> 1.0.0"
  s.add_development_dependency "jeweler", "~> 1.6.4"
  s.add_development_dependency "test-unit"
end
