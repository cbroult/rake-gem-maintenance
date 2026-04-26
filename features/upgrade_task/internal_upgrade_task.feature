Feature: InternalUpgradeTask for cbp-org only gems
  As a gem maintainer of internal gems
  I want to use a preset that publishes only to cbp-org
  So that I don't need to configure repositories

  Scenario: InternalUpgradeTask uses cbp-org only by default
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::InternalUpgradeTask.new

      task :show_repos do
        puts Rake::GemMaintenance::Repos.internal.inspect
      end
      """
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:auto"

  Scenario: InternalUpgradeTask uses Repos.internal
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      upgrade_task = Rake::GemMaintenance::InternalUpgradeTask.new

      task :show_repos do
        puts upgrade_task.gem_repositories.inspect
      end
      """
    When I successfully run `rake show_repos`
    Then the output should contain "[{name: \"cbp-org\", url: \"https://gems.cbp-org.internal\"}]"

  Scenario: InternalUpgradeTask defines upgrade:prepare_version
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::InternalUpgradeTask.new
      """
    When I successfully run `rake -T upgrade:prepare_version`
    Then the output should contain "upgrade:prepare_version"