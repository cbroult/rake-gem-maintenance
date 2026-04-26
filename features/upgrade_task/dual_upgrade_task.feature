Feature: DualUpgradeTask for both rubygems.org and cbp-org gems
  As a gem maintainer of public+internal gems
  I want to use a preset that publishes to both repos
  So that I don't need to configure repositories

  Scenario: DualUpgradeTask defaults to both repos
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::DualUpgradeTask.new

      task :show_repos do
        puts Rake::GemMaintenance::Repos.all.inspect
      end
      """
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:auto"

  Scenario: DualUpgradeTask uses Repos.all
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      upgrade_task = Rake::GemMaintenance::DualUpgradeTask.new

      task :show_repos do
        puts upgrade_task.gem_repositories.inspect
      end
      """
    When I successfully run `rake show_repos`
    Then the output should contain "[{name: \"rubygems\", url: \"https://rubygems.org\"}, {name: \"cbp-org\", url: \"https://gems.cbp-org.internal\"}]"

  Scenario: DualUpgradeTask defines upgrade:prepare_version
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::DualUpgradeTask.new
      """
    When I successfully run `rake -T upgrade:prepare_version`
    Then the output should contain "upgrade:prepare_version"