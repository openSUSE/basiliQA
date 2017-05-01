Gem::Specification.new do |s|
  s.name    = "testenv"
  s.version = ENV['VERSION']
  s.summary = "Access to basiliQA test environment"
  s.description = "Access to information about the outer environment of a test run by basiliQA and stored in an XML file."
  s.author  = "SUSE"
  s.homepage = "http://www.suse.com"
  s.license = "GPL-2"

  s.files = "ext/testenv/testenv.c", "ext/testenv/common.c", "ext/testenv/common.h"
  s.extensions = "ext/testenv/extconf.rb"

  s.add_development_dependency "rake-compiler"
end
