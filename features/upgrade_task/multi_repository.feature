Feature: Upgrade task multi-repository publishing
  As a gem maintainer publishing to multiple repositories
  I want to configure multiple gem repositories
  So that my gem is available on all required platforms

  Background:
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = [
          { name: "rubygems", url: "https://rubygems.org" },
          { name: "internal", url: "https://gems.cbp-org.internal" }
        ]
      end
      """

  Scenario: Includes default rubygems.org repository by default
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new
      """
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:prepare_version"

  Scenario: Lists all expected subtasks for multi-repo upgrade
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:auto"
    And the output should contain "upgrade:branch"
    And the output should contain "upgrade:gems"
    And the output should contain "upgrade:prepare_version"
    And the output should contain "upgrade:commit"
    And the output should contain "upgrade:push"

  Scenario: Defines the upgrade:prepare_version task
    When I successfully run `rake -T upgrade:prepare_version`
    Then the output should contain "rake upgrade:prepare_version"
    And the output should contain "Check version on all repositories before bumping"

  Scenario: Auto pipeline includes prepare_version step
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = [
          { name: "rubygems", url: "https://rubygems.org" },
          { name: "internal", url: "https://gems.cbp-org.internal" }
        ]
      end

      task :show_pipeline do
        auto_task = Rake::Task["upgrade:auto"]
        puts "pipeline: " + auto_task.prerequisites.inspect
      end
      """
    When I successfully run `rake show_pipeline`
    Then the output should contain:
      """
      pipeline: ["branch", "gems", "verify", "commit", "version:bump", "prepare_version", "release", "push"]
      """

  Scenario: prepare_version task is skipped when no gemspec exists
    When I successfully run `rake upgrade:prepare_version`
    Then the output should not contain "[INFO]"

  Scenario: prepare_version outputs info when gemspec exists with unpversioned version
    Given a file named "test-gem.gemspec" with:
      """
      Gem::Specification.new do |spec|
        spec.name = "test-gem"
        spec.version = "1.0.0"
        spec.authors = ["Test"]
        spec.summary = "Test gem"
      end
      """
    And a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      class MockPublisher
        def initialize(repositories)
          @repositories = repositories
          @failed = []
        end

        def check_all_repositories(gem_name)
        end

        def any_available?
          true
        end

        def failed_repositories
          @failed
        end

        def next_version(gem_name, current_version)
          current_version
        end
      end

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = [
          { name: "rubygems", url: "https://rubygems.org" },
          { name: "internal", url: "https://gems.cbp-org.internal" }
        ]
        t.gem_publisher_class = MockPublisher
      end
      """
    When I successfully run `rake upgrade:prepare_version`
    Then the output should contain "[INFO] Version 1.0.0 not found on any repository - will publish"

  Scenario: Has upgrade:info:repos task showing repos
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = [
          { name: "rubygems", url: "https://rubygems.org" },
          { name: "internal", url: "https://gems.cbp-org.internal" }
        ]
      end
      """
    When I successfully run `rake upgrade:info:repos`
    Then the output should contain "rubygems"
    And the output should contain "gems.cbp-org.internal"

  Scenario: Works with single repository
    Given a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = [
          { name: "rubygems", url: "https://rubygems.org" }
        ]
      end
      """
    When I successfully run `rake -T upgrade`
    Then the output should contain "upgrade:prepare_version"

  Scenario: One repository unavailable shows warning at end
    Given a file named "test-gem.gemspec" with:
      """
      Gem::Specification.new do |spec|
        spec.name = "test-gem"
        spec.version = "1.0.0"
        spec.authors = ["Test"]
        spec.summary = "Test gem"
      end
      """
    And a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      class MockPublisher
        def initialize(repositories)
          @repositories = repositories
        end

        def check_all_repositories(gem_name)
        end

        def any_available?
          true
        end

        def failed_repositories
          ["unavailable"]
        end

        def next_version(gem_name, current_version)
          current_version
        end
      end

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = [
          { name: "rubygems", url: "https://rubygems.org" },
          { name: "unavailable", url: "https://unavailable.example.com" }
        ]
        t.gem_publisher_class = MockPublisher
      end

      task :run_check do
        Rake::Task["upgrade:prepare_version"].invoke
      end
      """
    When I successfully run `rake run_check`
    Then the output should contain "[WARN]"
    And the output should contain "unavailable"
    And the output should contain "[INFO] Version"

  Scenario: All repositories unavailable shows error and exits non-zero
    Given a file named "test-gem.gemspec" with:
      """
      Gem::Specification.new do |spec|
        spec.name = "test-gem"
        spec.version = "1.0.0"
        spec.authors = ["Test"]
        spec.summary = "Test gem"
      end
      """
    And a file named "Rakefile" with:
      """
      require "rake/gem/maintenance/upgrade_task"

      class MockPublisher
        def initialize(repositories)
          @repositories = repositories
        end

        def check_all_repositories(gem_name)
        end

        def any_available?
          false
        end

        def failed_repositories
          ["offline1", "offline2"]
        end

        def next_version(gem_name, current_version)
          current_version
        end
      end

      Rake::GemMaintenance::UpgradeTask.new do |t|
        t.gem_repositories = [
          { name: "offline1", url: "https://offline1.example.com" },
          { name: "offline2", url: "https://offline2.example.com" }
        ]
        t.gem_publisher_class = MockPublisher
      end
      """
    When I run `rake upgrade:prepare_version`
    Then the exit status should not be 0
    And the output should contain "[ERROR]"
    And the output should contain "No repositories available"