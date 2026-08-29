Feature: Install tasks
  As a gem maintainer
  I want a single require to set up all tasks
  So that I can get started quickly

  Scenario: Defines both upgrade and version bump tasks
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/install_tasks"
      """
    When I successfully run `rake -T`
    Then the output should contain "upgrade"
    And the output should contain "upgrade:auto"
    And the output should contain "upgrade:branch"
    And the output should contain "version:bump"
    And the output should contain "bump[type]"

  Scenario: Releases through the OTP aware publish task
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/install_tasks"

      task :show_pipeline do
        puts "pipeline: " + Rake::Task["upgrade:auto"].prerequisites.inspect
      end
      """
    When I successfully run `rake show_pipeline`
    Then the output should contain "publish:release"
    And the output should not contain "\"release\""

  Scenario: Configures GEM_HOST_API_KEY as the rubygems API key env var
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/install_tasks"

      task :show_api_key_env_var do
        puts Rake::Gem::Maintenance::Repos.rubygems_api_key_env_var
      end
      """
    When I successfully run `rake show_api_key_env_var`
    Then the output should contain "GEM_HOST_API_KEY"

  Scenario: Configures RUBYGEMS_OTP_SEED as the rubygems OTP seed env var
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/install_tasks"

      task :show_otp_seed_env_var do
        puts Rake::Gem::Maintenance::Repos.rubygems_otp_seed_env_var
      end
      """
    When I successfully run `rake show_otp_seed_env_var`
    Then the output should contain "RUBYGEMS_OTP_SEED"
