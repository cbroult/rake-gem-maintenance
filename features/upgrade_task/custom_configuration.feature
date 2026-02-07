Feature: Upgrade task custom configuration
  As a gem maintainer
  I want to customize UpgradeTask
  So that it fits my project's workflow

  Scenario: Custom task name
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new(:deps)
      """
    When I successfully run `rake -T deps`
    Then the output should contain "rake deps "
    And the output should contain "Alias for deps:auto"
    And the output should contain "rake deps:auto"
    And the output should contain "rake deps:branch"

  Scenario: Custom verification task
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.verification_task = :test
      end

      task :show_pipeline do
        auto_task = Rake::Task["upgrade:auto"]
        puts "pipeline: " + auto_task.prerequisites.inspect
      end
      """
    When I successfully run `rake show_pipeline`
    Then the output should contain "\"test\""

  Scenario: Custom auto pipeline
    Given a file named "Rakefile" with:
      """
      require "rake/gem_maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.auto_pipeline = %i[branch gems commit push]
      end

      task :show_pipeline do
        auto_task = Rake::Task["upgrade:auto"]
        puts "pipeline: " + auto_task.prerequisites.inspect
      end
      """
    When I successfully run `rake show_pipeline`
    Then the output should contain:
      """
      pipeline: ["branch", "gems", "commit", "push"]
      """
