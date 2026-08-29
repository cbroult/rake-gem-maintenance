# frozen_string_literal: true

require "net/http"
require "rake"
require "rake/tasklib"
require_relative "ci_environment"
require_relative "otp_provider"
require_relative "renew_api_key_task"
require_relative "gem_publisher"
require_relative "repos"
require_relative "ruby_version_checker"
require_relative "ruby_version_updater"

module Rake
  module Gem
    module Maintenance
      # Defines Rake tasks for upgrading gem dependencies and publishing to multiple repositories.
      #
      # Creates: upgrade, upgrade:auto, upgrade:branch, upgrade:gems, upgrade:commit,
      # upgrade:prepare_version, upgrade:push
      # rubocop:disable Metrics/ClassLength, Metrics/MethodLength
      class UpgradeTask < ::Rake::TaskLib
        attr_accessor :name, :main_branch, :upgrade_branch, :commit_message,
                      :files_to_commit, :verification_task, :release_task,
                      :version_bump_task, :update_rubygems, :update_gems,
                      :run_bundle_audit, :auto_pipeline, :gem_repositories,
                      :gem_publisher_class, :gem_name, :gem_version,
                      :update_ruby, :ruby_version_checker_class, :ruby_version_updater_class

        attr_writer :renew_api_key_task_class

        def renew_api_key_task_class
          @renew_api_key_task_class || RenewApiKeyTask
        end

        def initialize(name = :upgrade)
          super()
          apply_default_configuration(name)

          yield self if block_given?
          define_tasks
        end

        def apply_default_configuration(name)
          @name = name
          @main_branch = "main"
          @upgrade_branch = "upgrade/gems"
          @commit_message = "chore(deps): upgrade gems"
          @files_to_commit = %w[Gemfile Gemfile.lock]
          @verification_task = :verify
          @release_task = :release
          @version_bump_task = "version:bump"
          @auto_pipeline = nil
          @gem_repositories = Repos.rubygems
          @gem_publisher_class = GemPublisher
          @gem_name = detect_gem_name
          @gem_version = detect_gem_version
          apply_default_gem_update_configuration
          apply_default_ruby_version_configuration
        end

        def apply_default_gem_update_configuration
          @update_rubygems = true
          @update_gems = true
          @run_bundle_audit = true
        end

        def apply_default_ruby_version_configuration
          @update_ruby = true
          @ruby_version_checker_class = RubyVersionChecker
          @ruby_version_updater_class = RubyVersionUpdater
        end

        private

        def detect_gem_name
          gemspec = Dir.glob("*.gemspec").first
          return nil unless gemspec

          ::Gem::Specification.load(gemspec).name
        end

        def detect_gem_version
          gemspec = Dir.glob("*.gemspec").first
          return nil unless gemspec

          ::Gem::Specification.load(gemspec).version.to_s
        end

        def repo_available?(repo)
          url = repo[:url]
          uri = URI.parse(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = 5
          http.start { |h| h.head("/").code.to_i < 400 }
        rescue StandardError
          false
        end

        public

        def define_tasks
          define_top_level_task
          define_info_tasks
          define_prepare_version_task
          define_auto_task
          define_branch_task
          define_gems_task
          define_commit_task
          define_push_task
          define_renew_api_key_task
        end

        def define_info_tasks
          task_instance = self
          namespace name do
            namespace :info do
              define_info_repos_task(task_instance)
              define_info_version_task(task_instance)
              define_info_name_task(task_instance)
              desc "Show all upgrade info"
              task all: %i[name version repos]
            end
            desc "Show all upgrade info"
            task info: "#{name}:info:all"
          end
        end

        def define_info_repos_task(task_instance)
          desc "Show configured gem repositories"
          task :repos do
            puts "Gem repositories:"
            task_instance.gem_repositories.each do |repo|
              available = task_instance.send(:repo_available?, repo)
              status = available ? "✓" : "✗"
              avail_text = available ? "AVAILABLE" : "NOT AVAILABLE"
              puts "  - #{repo[:name]} (#{status}) - #{avail_text}: #{repo[:url]}"
            end
          end
        end

        def define_info_version_task(task_instance)
          desc "Show current gem version"
          task :version do
            ver = task_instance.gem_version || "unknown"
            puts "Current version: #{ver}"
          end
        end

        def define_info_name_task(task_instance)
          desc "Show current gem name"
          task :name do
            name = task_instance.gem_name || "unknown"
            puts "Gem name: #{name}"
          end
        end

        def define_top_level_task
          desc "Alias for #{name}:auto"
          task name => "#{name}:auto"
        end

        def define_prepare_version_task
          task_instance = self
          namespace name do
            desc "Check version on all repositories before bumping"
            task :prepare_version do
              task_instance.send(:check_version_on_repositories)
            end
          end
        end

        def define_auto_task
          task_instance = self
          namespace name do
            desc "Update gems automatically (branch to push and release)"
            task auto: task_instance.send(:pipeline_tasks)
          end
        end

        def define_branch_task
          task_instance = self
          namespace name do
            desc "Create a branch for the upgrade"
            task(:branch) { task_instance.send(:create_upgrade_branch) }
          end
        end

        def define_gems_task
          task_instance = self
          namespace name do
            desc "Upgrade gems, including bundler and gem"
            task(:gems) { task_instance.send(:do_upgrade_gems) }
          end
        end

        def define_commit_task
          task_instance = self
          namespace name do
            desc "Commit the upgrade branch"
            task(:commit) { task_instance.send(:commit_changes) }
          end
        end

        def define_push_task
          task_instance = self
          namespace name do
            desc "Push the upgrade"
            task(:push) { task_instance.send(:push_branch) }
          end
        end

        def define_renew_api_key_task
          renew_api_key_task_class.new(name)
        end

        def pipeline_tasks
          return auto_pipeline if auto_pipeline

          %i[branch
             gems] + [verification_task, :commit, version_bump_task.to_sym, :prepare_version, release_task, :push]
        end

        def create_upgrade_branch
          sh "git checkout #{main_branch}"
          sh "git pull"
          sh "git branch -D #{upgrade_branch}" unless `git branch --list #{upgrade_branch}`.chomp.empty?
          sh "git checkout -b #{upgrade_branch}"
        end

        def do_upgrade_gems
          update_ruby_versions if update_ruby
          sh "gem update --system" if update_rubygems
          sh "gem update" if update_gems
          sh "bundle update --bundler"
          sh "bundle update --all"
          sh "bundle audit" if run_bundle_audit
        end

        def update_ruby_versions
          checker = ruby_version_checker_class.new
          if checker.latest_stable.nil?
            puts "[WARN] Could not fetch Ruby version info — skipping Ruby update"
            return
          end
          modified = ruby_version_updater_class.new.update(checker: checker)
          files_to_commit.concat(modified) if modified.any?
        end

        def commit_changes
          sh "git add #{files_to_commit.join(' ')}"
          sh "git commit -m '#{commit_message}'"
        end

        def push_branch
          sh "git push origin #{upgrade_branch}"
        end

        # rubocop:disable Metrics/AbcSize
        def check_version_on_repositories
          unless gem_name && gem_version
            puts "[ERROR] No gemspec found - cannot check version/upgrade"
            abort
          end

          publisher = gem_publisher_class.new(gem_repositories)
          publisher.check_all_repositories(gem_name)

          return unless repos_available?(publisher)

          print_failed_repository_warnings(publisher)
          version = gem_version
          next_ver = publisher.next_version(gem_name, version)

          if next_ver == version
            puts "[INFO] Version #{version} not found on any repository - will publish"
          else
            puts "[INFO] Version #{version} already published to all repositories"
            puts "[INFO] Next available version: #{next_ver}"
          end

          handle_partial_publish_warning(publisher, version)
        end
        # rubocop:enable Metrics/AbcSize

        def handle_partial_publish_warning(publisher, version)
          return if publisher.successful_repos.empty?

          published = publisher.successful_repos
          total = gem_repositories.size
          return unless published.size < total

          puts "[WARN] Version #{version} was only published to #{published.size} of #{total} repositories"
          puts "[WARN] Run 'rake upgrade:prepare_version' manually to check status"
        end

        def repos_available?(publisher)
          return true if publisher.any_available?

          puts "[ERROR] No repositories available. Cannot check version."
          abort
        end

        def print_failed_repository_warnings(publisher)
          return if publisher.failed_repositories.empty?

          puts "[WARN] The following repositories were unavailable:"
          publisher.failed_repositories.each do |repo_name|
            puts "  - #{repo_name}"
          end
        end
        # rubocop:enable Metrics/ClassLength, Metrics/MethodLength
      end

      # Upgrades gems and publishes to cbp-org only (internal gems).
      # Uses Repos.internal as default repositories.
      class InternalUpgradeTask < UpgradeTask
        def apply_default_configuration(name)
          super
          @gem_repositories = Repos.internal
        end
      end

      # Upgrades gems and publishes to both rubygems.org and cbp-org.
      # Uses Repos.all as default repositories.
      class DualUpgradeTask < UpgradeTask
        def apply_default_configuration(name)
          super
          @gem_repositories = Repos.all
        end
      end

      # Upgrades gems and publishes to a local geminabox instance only.
      # Uses Repos.geminabox as default repositories.
      class GeminaboxUpgradeTask < UpgradeTask
        def apply_default_configuration(name)
          super
          @gem_repositories = Repos.geminabox
        end
      end
    end
  end
end
