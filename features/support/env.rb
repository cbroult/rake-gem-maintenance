# frozen_string_literal: true

require "aruba/cucumber"

Aruba.configure do |config|
  config.exit_timeout = 30
  config.activate_announcer_on_command_failure = %i[stdout stderr]
end

Before do
  project_lib = File.expand_path("../../lib", __dir__)
  prepend_environment_variable("RUBYLIB", "#{project_lib}:")
  set_environment_variable("XDG_CONFIG_HOME", expand_path(".config"))
  %w[RUBYGEMS_USERNAME RUBYGEMS_PASSWORD RUBYGEMS_OTP_SEED GEM_HOST_API_KEY].each do |var|
    delete_environment_variable(var)
  end
end
