# frozen_string_literal: true

require "aruba/cucumber"

Aruba.configure do |config|
  config.exit_timeout = 30
  config.activate_announcer_on_command_failure = %i[stdout stderr]
end

Before do
  project_lib = File.expand_path("../../lib", __dir__)
  prepend_environment_variable("RUBYLIB", "#{project_lib}:")
end
