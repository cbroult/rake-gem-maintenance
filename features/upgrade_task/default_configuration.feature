Feature: Upgrade task default configuration
  As a gem maintainer
  I want UpgradeTask to have sensible defaults
  So that I can use it without configuration

  Background:
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new
      """

  Scenario: Lists all expected subtasks
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:auto"
    And the output should contain "upgrade:branch"
    And the output should contain "upgrade:gems"
    And the output should contain "upgrade:commit"
    And the output should contain "upgrade:push"

  Scenario: Auto pipeline includes default steps in order
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new

      task :show_pipeline do
        auto_task = Rake::Task["upgrade:auto"]
        puts "pipeline: " + auto_task.prerequisites.inspect
      end
      """
    When I successfully run `rake show_pipeline`
    Then the output should contain:
      """
      pipeline: ["branch", "gems", "verify", "commit", "version:bump", "release", "push"]
      """
