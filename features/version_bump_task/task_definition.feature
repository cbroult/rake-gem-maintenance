Feature: Version bump task definition
  As a gem maintainer
  I want VersionBumpTask to define version bump Rake tasks
  So that I can bump versions easily

  Background:
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/version_bump_task"

      Rake::GemMaintenance::VersionBumpTask.new
      """

  Scenario: Defines the version:bump task
    When I successfully run `rake -T version:bump`
    Then the output should contain "rake version:bump[type]"
    And the output should contain "Bump version (patch, minor, major) and update Gemfile.lock"

  Scenario: Defines the bump alias task
    When I successfully run `rake -T bump`
    Then the output should contain "rake bump[type]"
    And the output should contain "Alias for version:bump"

  Scenario: Description shows default type
    When I successfully run `rake -D version:bump`
    Then the output should contain "Default: patch"
