Feature: DualUpgradeTask for both rubygems.org and cbp-org gems
  As a gem maintainer of public+internal gems
  I want to use a preset that publishes to both repos
  So that I don't need to configure repositories

  Scenario: DualUpgradeTask creates upgrade tasks
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::DualUpgradeTask.new
      ```
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:auto"
    And the output should contain "upgrade:branch"
    And the output should contain "upgrade:commit"
    And the output should contain "upgrade:gems"
    And the output should contain "upgrade:prepare_version"
    And the output should contain "upgrade:push"

  Scenario: DualUpgradeTask uses both repositories by default
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      upgrade_task = Rake::GemMaintenance::DualUpgradeTask.new

      task :show_repos do
        puts "Repositories: #{upgrade_task.gem_repositories}"
      end
      ```
    When I successfully run `rake show_repos`
    Then the output should contain:
      ```
      Repositories: [{name: "rubygems", url: "https://rubygems.org"}, {name: "cbp-org", url: "https://gems.cbp-org.internal"}]
      ```

  Scenario: DualUpgradeTask has prepare_version task
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::DualUpgradeTask.new
      ```
    When I successfully run `rake -T upgrade:prepare_version`
    Then the output should contain "upgrade:prepare_version"