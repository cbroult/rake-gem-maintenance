Feature: Upgrade task definition
  As a gem maintainer
  I want UpgradeTask to define upgrade-related Rake tasks
  So that I can automate dependency upgrades

  Background:
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new
      """

  Scenario: Defines the upgrade alias task
    When I successfully run `rake -T upgrade`
    Then the output should contain "rake upgrade "
    And the output should contain "Alias for upgrade:auto"

  Scenario: Defines the upgrade:auto task
    When I successfully run `rake -T upgrade:auto`
    Then the output should contain "rake upgrade:auto"
    And the output should contain "Update gems automatically (branch to push and release)"

  Scenario: Defines the upgrade:branch task
    When I successfully run `rake -T upgrade:branch`
    Then the output should contain "rake upgrade:branch"
    And the output should contain "Create a branch for the upgrade"

  Scenario: Defines the upgrade:gems task
    When I successfully run `rake -T upgrade:gems`
    Then the output should contain "rake upgrade:gems"
    And the output should contain "Upgrade gems, including bundler and gem"

  Scenario: Defines the upgrade:commit task
    When I successfully run `rake -T upgrade:commit`
    Then the output should contain "rake upgrade:commit"
    And the output should contain "Commit the upgrade branch"

  Scenario: Defines the upgrade:push task
    When I successfully run `rake -T upgrade:push`
    Then the output should contain "rake upgrade:push"
    And the output should contain "Push the upgrade"
