Feature: Version bump task custom configuration
  As a gem maintainer
  I want to customize VersionBumpTask
  So that it fits my project's workflow

  Scenario: Custom namespace
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/version_bump_task"

      Rake::GemMaintenance::VersionBumpTask.new do |t|
        t.namespace_name = :ver
      end
      """
    When I successfully run `rake -T ver:bump`
    Then the output should contain "rake ver:bump[type]"

  Scenario: Disabling the bump alias
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/version_bump_task"

      Rake::GemMaintenance::VersionBumpTask.new do |t|
        t.create_alias = false
      end
      """
    When I successfully run `rake -T`
    Then the output should contain "version:bump"
    And the output should not contain "rake bump"

  Scenario: Custom default type shown in description
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/version_bump_task"

      Rake::GemMaintenance::VersionBumpTask.new do |t|
        t.default_type = "minor"
      end
      """
    When I successfully run `rake -D version:bump`
    Then the output should contain "Default: minor"
