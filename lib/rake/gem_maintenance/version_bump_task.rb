# frozen_string_literal: true

require "rake"
require "rake/tasklib"

module Rake
  module GemMaintenance
    # Defines Rake tasks for version bumping with gem-release.
    #
    # Creates: version:bump[type] and bump[type] (alias)
    class VersionBumpTask < ::Rake::TaskLib
      VALID_TYPES = %w[patch minor major].freeze

      attr_accessor :namespace_name, :default_type, :commit_message_template,
                    :create_alias, :amend_with_gemfile_lock

      def initialize
        super
        @namespace_name = :version
        @default_type = "patch"
        @commit_message_template = "chore(release): %<version>s"
        @create_alias = true
        @amend_with_gemfile_lock = true

        yield self if block_given?

        define_tasks
      end

      private

      def define_tasks
        define_version_bump_task
        define_alias_task if create_alias
      end

      def define_version_bump_task
        task_instance = self
        bump_desc = "Bump version (patch, minor, major) and update Gemfile.lock. Default: #{default_type}"

        namespace namespace_name do
          desc bump_desc
          task :bump, [:type] do |_t, args|
            task_instance.send(:run_bump, args)
          end
        end
      end

      def define_alias_task
        ns = namespace_name

        desc "Alias for #{ns}:bump"
        task :bump, [:type] => ["#{ns}:bump"]
      end

      def run_bump(args)
        args.with_defaults(type: default_type)

        validate_version_type(args.type)
        execute_version_bump(args.type)

        return unless amend_with_gemfile_lock

        update_gemfile_lock
        amend_commit_to_include_gemfile_lock_changes
      end

      def validate_version_type(type)
        return if VALID_TYPES.include?(type)

        abort "Error: Version type must be one of: #{VALID_TYPES.join(', ')}"
      end

      def execute_version_bump(type)
        puts "Bumping #{type} version..."
        bump_result = system("bundle exec gem bump --version #{type} --message '#{commit_message_template}'")
        return if bump_result

        abort "Error: Failed to bump version"
      end

      def update_gemfile_lock
        puts "Updating Gemfile.lock..."
        bundle_result = system("bundle install")
        return if bundle_result

        abort "Error: Failed to update Gemfile.lock"
      end

      def amend_commit_to_include_gemfile_lock_changes
        puts "Amending commit to include Gemfile.lock update..."
        system("git add .")
        system("git commit --amend --no-edit")
      end
    end
  end
end
