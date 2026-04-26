Feature: InternalUpgradeTask for cbp-org only gems
  As a gem maintainer of internal gems
  I want to use a preset that publishes only to cbp-org
  So that I don't need to configure repositories

  Scenario: InternalUpgradeTask creates upgrade tasks
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::InternalUpgradeTask.new
      ```
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:auto"
    And the output should contain "upgrade:branch"
    And the output should contain "upgrade:commit"
    And the output should contain "upgrade:gems"
    And the output should contain "upgrade:prepare_version"
    And the output should contain "upgrade:push"

  Scenario: InternalUpgradeTask uses cbp-org only by default
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      upgrade_task = Rake::GemMaintenance::InternalUpgradeTask.new

      task :show_repos do
        puts "Repositories: #{upgrade_task.gem_repositories}"
      end
      ```
    When I successfully run `rake show_repos`
    Then the output should contain:
      ```
      Repositories: [{name: "cbp-org", url: "https://gems.cbp-org.internal"}]
      ```

  Scenario: InternalUpgradeTask has prepare_version task
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::InternalUpgradeTask.new
      ```
    When I successfully run `rake -T upgrade:prepare_version`
    Then the output should contain "upgrade:prepare_version"

  Scenario: InternalUpgradeTask has info:repos task showing cbp-org
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::InternalUpgradeTask.new
      ```
    When I successfully run `rake upgrade:info:repos`
    Then the output should contain "cbp-org"
    And the output should contain "gems.cbp-org.internal"