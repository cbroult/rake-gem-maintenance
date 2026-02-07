Feature: Version bump task validation
  As a gem maintainer
  I want invalid version types to be rejected
  So that I get clear feedback on mistakes

  Background:
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/version_bump_task"

      Rake::GemMaintenance::VersionBumpTask.new
      """

  Scenario: Rejects an invalid version type
    When I run `rake "version:bump[invalid]"`
    Then the exit status should not be 0
    And the output should contain "Version type must be one of: patch, minor, major"
