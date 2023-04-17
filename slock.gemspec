lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'slock/version'

Gem::Specification.new do |s|
  s.name        = "slock"
  s.version     = Slock::VERSION
  s.summary     = "Sempahore Lock"
  s.description = "Gem provide Semaphore lock via Redis"
  s.authors     = ["Oleg Yashchuk"]
  s.email       = "oazoer@gmail.com"
  s.files         = Dir["{lib}/**/*", "CHANGELOG.md", "MIT-LICENSE", "README.md"]
  s.homepage    = "https://github.com/zoer/slock"
  s.license     = "MIT"

  s.add_dependency 'redis'

  s.add_development_dependency 'redis-namespace'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'timecop'
end
