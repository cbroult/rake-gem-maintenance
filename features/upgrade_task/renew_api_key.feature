Feature: RenewApiKeyTask for renewing rubygems.org API key
  As a gem maintainer
  I want a rake task to renew my rubygems.org API key
  So that I can rotate credentials without leaving the terminal

  Scenario: RenewApiKeyTask defines upgrade:renew_api_key
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance"

      Rake::Gem::Maintenance::RenewApiKeyTask.new
      ```
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:renew_api_key"

  Scenario: RenewApiKeyTask with custom namespace
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance"

      Rake::Gem::Maintenance::RenewApiKeyTask.new(:deploy)
      ```
    When I successfully run `rake -T deploy`
    Then the output should contain "deploy:renew_api_key"

  Scenario: renew_api_key task aborts in CI with actionable message
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance"

      Rake::Gem::Maintenance::RenewApiKeyTask.new
      ```
    When I set the environment variables to:
      | variable | value |
      | CI       | true  |
    And I run `rake upgrade:renew_api_key`
    Then the exit status should not be 0
    And the output should contain "RUBYGEMS_USERNAME"
    And the output should contain "RUBYGEMS_PASSWORD"
