Feature: Ruby version upgrade via RubyVersionUpdater

  Scenario: updates .ruby-version to latest stable
    Given a file named "update_ruby.rb" with:
      """
      require "rake/gem/maintenance/ruby_version_updater"
      checker = Class.new {
        def latest_stable = "4.1.0"
        def maintained_minors = %w[3.4 4.0 4.1]
      }.new
      Rake::Gem::Maintenance::RubyVersionUpdater.new.update(checker: checker)
      """
    When I successfully run `ruby update_ruby.rb`
    Then a file named ".ruby-version" should exist
    And the file ".ruby-version" should contain "4.1.0"

  Scenario: updates gemspec required_ruby_version patch within same minor
    Given a file named "test.gemspec" with:
      """
      s = Gem::Specification.new
      s.required_ruby_version = ">= 4.0.1"
      """
    And a file named "update_ruby.rb" with:
      """
      require "rake/gem/maintenance/ruby_version_updater"
      checker = Class.new {
        def latest_stable = "4.0.3"
        def maintained_minors = %w[3.4 4.0]
      }.new
      Rake::Gem::Maintenance::RubyVersionUpdater.new(
        gemspec_files: ["test.gemspec"]
      ).update(checker: checker)
      """
    When I successfully run `ruby update_ruby.rb`
    Then the file "test.gemspec" should contain ">= 4.0.3"

  Scenario: does not change required_ruby_version when minor differs
    Given a file named "test.gemspec" with:
      """
      s = Gem::Specification.new
      s.required_ruby_version = ">= 3.4.0"
      """
    And a file named "update_ruby.rb" with:
      """
      require "rake/gem/maintenance/ruby_version_updater"
      checker = Class.new {
        def latest_stable = "4.1.0"
        def maintained_minors = %w[3.4 4.0 4.1]
      }.new
      Rake::Gem::Maintenance::RubyVersionUpdater.new(
        gemspec_files: ["test.gemspec"]
      ).update(checker: checker)
      """
    When I successfully run `ruby update_ruby.rb`
    Then the file "test.gemspec" should contain ">= 3.4.0"

  Scenario: updates GitHub Actions matrix to maintained minors
    Given a file named "main.yml" with:
      """
      ruby-version: [ '3.4', '4.0', 'truffleruby' ]
      """
    And a file named "update_ruby.rb" with:
      """
      require "rake/gem/maintenance/ruby_version_updater"
      checker = Class.new {
        def latest_stable = "4.1.0"
        def maintained_minors = %w[3.4 4.0 4.1]
      }.new
      Rake::Gem::Maintenance::RubyVersionUpdater.new(
        github_workflow_files: ["main.yml"],
        woodpecker_config_files: []
      ).update(checker: checker)
      """
    When I successfully run `ruby update_ruby.rb`
    Then the file "main.yml" should contain "'3.4', '4.0', '4.1', 'truffleruby'"

  Scenario: updates Woodpecker Docker image tag
    Given a file named "verify.yml" with:
      """
      image: ruby:4.0.2-alpine
      """
    And a file named "update_ruby.rb" with:
      """
      require "rake/gem/maintenance/ruby_version_updater"
      checker = Class.new {
        def latest_stable = "4.1.0"
        def maintained_minors = %w[3.4 4.0 4.1]
      }.new
      Rake::Gem::Maintenance::RubyVersionUpdater.new(
        woodpecker_config_files: ["verify.yml"]
      ).update(checker: checker)
      """
    When I successfully run `ruby update_ruby.rb`
    Then the file "verify.yml" should contain "ruby:4.1.0-alpine"

  Scenario: warns and skips when checker returns no version
    Given a file named "update_ruby.rb" with:
      """
      require "rake/gem/maintenance/ruby_version_updater"
      checker = Class.new {
        def latest_stable = nil
        def maintained_minors = []
      }.new
      result = Rake::Gem::Maintenance::RubyVersionUpdater.new.update(checker: checker)
      puts result.inspect
      """
    When I successfully run `ruby update_ruby.rb`
    Then the output should contain "[]"
    And a file named ".ruby-version" should not exist
