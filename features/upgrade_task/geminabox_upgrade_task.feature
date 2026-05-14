Feature: GeminaboxUpgradeTask for local geminabox gems
  As a gem maintainer using a local geminabox instance
  I want to use a preset that publishes only to geminabox
  So that I don't need to configure repositories

  Scenario: GeminaboxUpgradeTask creates upgrade tasks
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::GeminaboxUpgradeTask.new
      ```
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:auto"
    And the output should contain "upgrade:branch"
    And the output should contain "upgrade:commit"
    And the output should contain "upgrade:gems"
    And the output should contain "upgrade:prepare_version"
    And the output should contain "upgrade:push"

  Scenario: GeminaboxUpgradeTask uses geminabox only by default
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      upgrade_task = Rake::GemMaintenance::GeminaboxUpgradeTask.new

      task :show_repos do
        puts "Repositories: #{upgrade_task.gem_repositories}"
      end
      ```
    When I successfully run `rake show_repos`
    Then the output should contain "geminabox"
    And the output should contain "http://localhost:9292"

  Scenario: GeminaboxUpgradeTask has prepare_version task
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::GeminaboxUpgradeTask.new
      ```
    When I successfully run `rake -T upgrade:prepare_version`
    Then the output should contain "upgrade:prepare_version"

  Scenario: GeminaboxUpgradeTask has renew_api_key task
    Given a file named "Rakefile" with:
      ```
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::GeminaboxUpgradeTask.new
      ```
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:renew_api_key"
