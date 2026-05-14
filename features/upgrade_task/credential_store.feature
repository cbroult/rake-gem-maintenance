Feature: CredentialStore persists API key and OTP seed locally

  Scenario: install_tasks loads GEM_HOST_API_KEY from credentials file
    Given a file named ".config/rake-gem-maintenance/credentials.yml" with:
      """
      gem_host_api_key: stored-api-key-123
      """
    And a file named "check_env.rb" with:
      """
      require "rake/gem/maintenance/install_tasks"
      puts ENV["GEM_HOST_API_KEY"]
      """
    When I successfully run `ruby check_env.rb`
    Then the output should contain "stored-api-key-123"

  Scenario: install_tasks loads RUBYGEMS_OTP_SEED from credentials file
    Given a file named ".config/rake-gem-maintenance/credentials.yml" with:
      """
      rubygems_otp_seed: MYSECRETOTP
      """
    And a file named "check_env.rb" with:
      """
      require "rake/gem/maintenance/install_tasks"
      puts ENV["RUBYGEMS_OTP_SEED"]
      """
    When I successfully run `ruby check_env.rb`
    Then the output should contain "MYSECRETOTP"

  Scenario: env var takes precedence over credentials file
    Given a file named ".config/rake-gem-maintenance/credentials.yml" with:
      """
      gem_host_api_key: from-file
      """
    And a file named "check_env.rb" with:
      """
      require "rake/gem/maintenance/install_tasks"
      puts ENV["GEM_HOST_API_KEY"]
      """
    When I set the environment variables to:
      | variable         | value    |
      | GEM_HOST_API_KEY | from-env |
    And I successfully run `ruby check_env.rb`
    Then the output should contain "from-env"
    And the output should not contain "from-file"

  Scenario: renew_api_key does not abort in CI when username is in credentials file
    Given a file named ".config/rake-gem-maintenance/credentials.yml" with:
      """
      username: stored-user
      """
    And a file named "Rakefile" with:
      """
      require "rake/gem/maintenance"
      Rake::GemMaintenance::RenewApiKeyTask.new
      """
    When I set the environment variables to:
      | variable          | value    |
      | CI                | true     |
      | RUBYGEMS_PASSWORD | testpass |
    And I run `rake upgrade:renew_api_key`
    Then the output should not contain "Set RUBYGEMS_USERNAME"

  Scenario: credentials file is written with restricted permissions on Unix
    Given a file named "write_creds.rb" with:
      """
      require "rake/gem/maintenance/credential_store"
      store = Rake::GemMaintenance::CredentialStore.new
      store.write(gem_host_api_key: "test-key")
      puts format("%o", File.stat(store.path).mode & 0o777)
      """
    When I successfully run `ruby write_creds.rb`
    Then the output should contain "600"
