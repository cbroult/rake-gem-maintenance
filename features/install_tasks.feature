Feature: Install tasks
  As a gem maintainer
  I want a single require to set up all tasks
  So that I can get started quickly

  Scenario: Defines both upgrade and version bump tasks
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/install_tasks"
      """
    When I successfully run `rake -T`
    Then the output should contain "upgrade"
    And the output should contain "upgrade:auto"
    And the output should contain "upgrade:branch"
    And the output should contain "version:bump"
    And the output should contain "bump[type]"
