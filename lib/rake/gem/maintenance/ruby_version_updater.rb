# frozen_string_literal: true

module Rake
  module Gem
    module Maintenance
      # Updates Ruby version references in .ruby-version, gemspec, and CI config files.
      class RubyVersionUpdater
        def initialize(
          ruby_version_file: ".ruby-version",
          gemspec_files: Dir.glob("*.gemspec"),
          github_workflow_files: Dir.glob(".github/workflows/*.yml"),
          woodpecker_config_files: Dir.glob(".woodpecker/*.yml")
        )
          @ruby_version_file = ruby_version_file
          @gemspec_files = Array(gemspec_files)
          @github_workflow_files = Array(github_workflow_files)
          @woodpecker_config_files = Array(woodpecker_config_files)
        end

        def update(checker:)
          latest = checker.latest_stable
          minors = checker.maintained_minors
          return [] if latest.nil? || minors.empty?

          [
            write_ruby_version_file(latest),
            *@gemspec_files.map { |f| patch_gemspec(f, latest) },
            *@github_workflow_files.map { |f| patch_github_workflow(f, minors) },
            *@woodpecker_config_files.map { |f| patch_woodpecker_config(f, latest) }
          ].compact
        end

        private

        def write_ruby_version_file(latest)
          current = File.exist?(@ruby_version_file) ? File.read(@ruby_version_file).strip : nil
          return if current == latest

          File.write(@ruby_version_file, "#{latest}\n")
          @ruby_version_file
        end

        def patch_gemspec(path, latest)
          return unless File.exist?(path)

          content = File.read(path)
          updated = rewrite_required_ruby_version(content, latest)
          return if updated == content

          File.write(path, updated)
          path
        end

        def patch_github_workflow(path, minors)
          return unless File.exist?(path)

          matrix_value = (minors + ["truffleruby"]).map { |v| "'#{v}'" }.join(", ")
          content = File.read(path)
          updated = content.gsub(/ruby-version:\s*\[.*?\]/, "ruby-version: [ #{matrix_value} ]")
          return if updated == content

          File.write(path, updated)
          path
        end

        def patch_woodpecker_config(path, latest)
          return unless File.exist?(path)

          content = File.read(path)
          updated = content.gsub(/\bruby:(\d+\.\d+\.\d+)([-\w]*)/, "ruby:#{latest}\\2")
          return if updated == content

          File.write(path, updated)
          path
        end

        def rewrite_required_ruby_version(content, latest)
          latest_parts = latest.split(".").map(&:to_i)
          content.gsub(/required_ruby_version\s*=\s*["'](>=\s*)(\d+)\.(\d+)\.\d+["']/) do
            prefix = ::Regexp.last_match(1)
            req_major = ::Regexp.last_match(2).to_i
            req_minor = ::Regexp.last_match(3).to_i
            next ::Regexp.last_match(0) unless same_minor?(req_major, req_minor, latest_parts)

            "required_ruby_version = \"#{prefix}#{latest}\""
          end
        end

        def same_minor?(major, minor, latest_parts)
          latest_parts[0] == major && latest_parts[1] == minor
        end
      end
    end
  end
end
