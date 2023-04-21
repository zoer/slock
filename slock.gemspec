lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'slock/version'

Gem::Specification.new do |s|
  s.name        = 'slock'
  s.version     = Slock::VERSION
  s.summary     = 'Sempahore Lock'
  s.description = 'Gem provide Semaphore lock via Redis'
  s.authors     = ['Oleg Yashchuk']
  s.email       = 'oazoer@gmail.com'
  s.files = Dir['{lib}/**/*', 'CHANGELOG.md', 'MIT-LICENSE', 'README.md']
  s.homepage    = 'https://github.com/zoer/slock'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.6.0'

  s.add_dependency 'redis', '>= 4.0'

  s.metadata['rubygems_mfa_required'] = 'true'
end
