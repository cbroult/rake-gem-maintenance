Feature: Local credential store for rubygems.org API key and OTP seed
  As a gem maintainer
  I want my API key and OTP seed stored locally after the first setup
  So that gem push and key renewal work automatically without re-entering credentials

  # Aruba sets HOME to its sandbox directory, so the credential file is written
  # to the Aruba tmp dir and never touches the developer's real ~/.config.

  @mocked-home-directory
  Scenario: install_tasks auto-loads API key from the credential file
    Given a file named ".config/rake-gem-maintenance/credentials.yml" with:
      """
      gem_host_api_key: stored-api-key-123
      """
    And a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/install_tasks"

      task :show_key do
        puts ENV["GEM_HOST_API_KEY"]
      end
      """
    When I successfully run `rake show_key`
    Then the output should contain "stored-api-key-123"

  @mocked-home-directory
  Scenario: install_tasks auto-loads OTP seed from the credential file
    Given a file named ".config/rake-gem-maintenance/credentials.yml" with:
      """
      rubygems_otp_seed: MYSECRETOTP
      """
    And a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/install_tasks"

      task :show_seed do
        puts ENV["RUBYGEMS_OTP_SEED"]
      end
      """
    When I successfully run `rake show_seed`
    Then the output should contain "MYSECRETOTP"

  @mocked-home-directory
  Scenario: An env var already set takes precedence over the credential file
    Given a file named ".config/rake-gem-maintenance/credentials.yml" with:
      """
      gem_host_api_key: from-file
      """
    And a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/install_tasks"

      task :show_key do
        puts ENV["GEM_HOST_API_KEY"]
      end
      """
    When I set the environment variables to:
      | variable        | value    |
      | GEM_HOST_API_KEY | from-env |
    And I successfully run `rake show_key`
    Then the output should contain "from-env"
    And the output should not contain "from-file"

  @mocked-home-directory
  Scenario: renew_api_key task in CI uses username from credential file
    Given a file named ".config/rake-gem-maintenance/credentials.yml" with:
      """
      username: storeduser
      """
    And a file named "Rakefile" with:
      """
      require "rake/gem/maintenance"
      Rake::GemMaintenance::RenewApiKeyTask.new
      """
    When I set the environment variables to:
      | variable          | value     |
      | CI                | true      |
      | RUBYGEMS_PASSWORD | testpass  |
    And I run `rake upgrade:renew_api_key`
    Then the exit status should not be 0
    But the output should not contain "Set RUBYGEMS_USERNAME"
