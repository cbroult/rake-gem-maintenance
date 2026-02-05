# frozen_string_literal: true

require "rake"
require "rake/gem_maintenance"

Rake::TaskManager.record_task_metadata = true

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
