# frozen_string_literal: true

require "rake"
require "rake/tasklib"
require_relative "gem_publisher"

module Rake
  module GemMaintenance
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
                    :gem_publisher_class, :gem_name, :gem_version

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
        @update_rubygems = true
        @update_gems = true
        @run_bundle_audit = true
        @auto_pipeline = nil
        @gem_repositories = default_repositories
        @gem_publisher_class = GemPublisher
        @gem_name = detect_gem_name
        @gem_version = detect_gem_version
      end

      private

      def default_repositories
        [{ name: "rubygems", url: "https://rubygems.org" }]
      end

      def detect_gem_name
        gemspec = Dir.glob("*.gemspec").first
        return nil unless gemspec

        Gem::Specification.load(gemspec).name
      end

      def detect_gem_version
        gemspec = Dir.glob("*.gemspec").first
        return nil unless gemspec

        Gem::Specification.load(gemspec).version.to_s
      end

      def define_tasks
        define_top_level_task
        define_prepare_version_task
        define_auto_task
        define_branch_task
        define_gems_task
        define_commit_task
        define_push_task
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

      def pipeline_tasks
        return auto_pipeline if auto_pipeline

        %i[branch gems] + [verification_task, :commit, version_bump_task.to_sym, :prepare_version, release_task, :push]
      end

      def create_upgrade_branch
        sh "git checkout #{main_branch}"
        sh "git pull"
        sh "git branch -D #{upgrade_branch}" unless `git branch --list #{upgrade_branch}`.chomp.empty?
        sh "git checkout -b #{upgrade_branch}"
      end

      def do_upgrade_gems
        sh "gem update --system" if update_rubygems
        sh "gem update" if update_gems
        sh "bundle update --bundler"
        sh "bundle update --all"
        sh "bundle audit" if run_bundle_audit
      end

      def commit_changes
        sh "git add #{files_to_commit.join(' ')}"
        sh "git commit -m '#{commit_message}'"
      end

      def push_branch
        sh "git push origin #{upgrade_branch}"
      end

      def check_version_on_repositories
        return unless gem_name
        return unless gem_version

        publisher = gem_publisher_class.new(gem_repositories)
        publisher.check_all_repositories(gem_name)

        return unless repos_available?(publisher)

        print_failed_repository_warnings(publisher)
        version = gem_version
        next_ver = publisher.next_version(gem_name, version)

        if next_ver == version
          puts "[INFO] Version #{version} not found on any repository - will publish"
        else
          puts "[INFO] Version #{version} already published"
          puts "[INFO] Next available version: #{next_ver}"
        end
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
  end
end
