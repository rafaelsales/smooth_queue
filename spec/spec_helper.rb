Bundler.require(:default, :test)

ENV['REDIS_URL'] ||= 'redis://127.0.0.1:6379/15'
Redis.new.flushall

SmoothQueue.configure do |config|
  config.add_queue('heavy_lifting', 5) do |id, message|
  end

  config.add_queue('very_heavy_lifting', 2) do |id, message|
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true # Default on RSpec 4
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups # Default on RSpec 4
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'tmp/spec_examples.txt'
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.profile_examples = 3
  config.order = :random
  Kernel.srand config.seed
end
