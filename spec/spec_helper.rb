require 'slock'
require 'redis'
require 'redis-namespace'
require 'timecop'
require 'byebug'

$VERBOSE = nil
root = File.expand_path('..', __dir__)
Dir[File.join(root, 'spec/support/**/*.rb')].sort.each { |f| require f }

RSpec::Matchers.define_negated_matcher :avoid_changing, :change

RSpec.configure do |config|
  config.include RedisHelpers
  config.warnings = false

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.order = :random

  config.before do
    keys = redis.keys('*')
    redis.del(*keys) if keys.count > 0
  end
end
