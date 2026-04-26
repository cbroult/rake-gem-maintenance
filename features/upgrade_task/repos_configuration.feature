Feature: Gem repository configurations
  As a gem maintainer
  I want to use pre-configured repository sets
  So that I don't repeat URLs across projects

Scenario: Repos.internal returns only cbp-org repository
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/repos"

      task :show_repos do
        puts Rake::GemMaintenance::Repos.internal.inspect
      end
      """
    When I successfully run `rake show_repos`
    Then the output should contain "[{name: \"cbp-org\", url: \"https://gems.cbp-org.internal\"}]"

  Scenario: Repos.all returns both rubygems.org and cbp-org
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/repos"

      task :show_repos do
        puts Rake::GemMaintenance::Repos.all.inspect
      end
      """
    When I successfully run `rake show_repos`
    Then the output should contain "[{name: \"rubygems\", url: \"https://rubygems.org\"}, {name: \"cbp-org\", url: \"https://gems.cbp-org.internal\"}]"

  Scenario: Repos.rubygems returns only rubygems.org
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/repos"

      task :show_repos do
        puts Rake::GemMaintenance::Repos.rubygems.inspect
      end
      """
    When I successfully run `rake show_repos`
    Then the output should contain "[{name: \"rubygems\", url: \"https://rubygems.org\"}]"

  Scenario: Repos.default equals Repos.rubygems
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/repos"

      task :show_repos do
        default_repos = Rake::GemMaintenance::Repos.default
        rubygems_repos = Rake::GemMaintenance::Repos.rubygems
        puts "equal: " + (default_repos == rubygems_repos).to_s
      end
      """
    When I successfully run `rake show_repos`
    Then the output should contain "equal: true"

  Scenario: UpgradeTask uses Repos.internal for internal-only gems
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"
      require "rake/gem/maintenance/repos"

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = Rake::GemMaintenance::Repos.internal
      end
      """
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:prepare_version"

  Scenario: UpgradeTask uses Repos.all for gems published to both
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"
      require "rake/gem/maintenance/repos"

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = Rake::GemMaintenance::Repos.all
      end
      """
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:prepare_version"

  Scenario: Can reconfigure internal URL
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/repos"

      Rake::GemMaintenance::Repos.internal_url = "https://my-internal.example.com"

      task :show_repos do
        puts Rake::GemMaintenance::Repos.internal.inspect
      end
      """
    When I successfully run `rake show_repos`
    Then the output should contain "https://my-internal.example.com"

  Scenario: Can reconfigure rubygems URL
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/repos"

      Rake::GemMaintenance::Repos.rubygems_url = "https://private-rubygems.example.com"

      task :show_repos do
        puts Rake::GemMaintenance::Repos.rubygems.inspect
      end
      """
    When I successfully run `rake show_repos`
    Then the output should contain "https://private-rubygems.example.com"