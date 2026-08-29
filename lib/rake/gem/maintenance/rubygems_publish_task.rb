# frozen_string_literal: true

require "rake"
require "rake/tasklib"
require_relative "gem_publisher"
require_relative "repos"

module Rake
  module Gem
    module Maintenance
      # Defines the publish:rubygems and publish:release Rake tasks for pushing a built .gem
      # to rubygems.org.
      #
      # publish:rubygems expects a .gem file to already exist (run gem build first).
      # publish:release reuses the bundler/gem_tasks steps to build, tag and push git, then
      # publishes through GemPublisher, which supports repositories requiring an OTP.
      # Uses the GEM_HOST_API_KEY and RUBYGEMS_OTP_SEED env vars configured via Repos.
      class RubygemsPublishTask < ::Rake::TaskLib
        GEM_FILE_GLOB = "{pkg/*.gem,*.gem}"
        RELEASE_PREREQUISITES = %w[build release:guard_clean release:source_control_push
                                   publish:rubygems].freeze

        attr_accessor :gem_file_glob, :gem_publisher_class, :release_prerequisites

        def initialize
          super
          @gem_file_glob = GEM_FILE_GLOB
          @gem_publisher_class = GemPublisher
          @release_prerequisites = RELEASE_PREREQUISITES

          yield self if block_given?
          define_tasks
        end

        private

        def define_tasks
          task_instance = self
          namespace :publish do
            desc "Push the built .gem file to rubygems.org"
            task :rubygems do
              task_instance.send(:publish_to_rubygems)
            end

            desc "Build, tag, push git and publish to rubygems.org (OTP aware)"
            task release: task_instance.release_prerequisites
          end
        end

        def publish_to_rubygems
          publisher = gem_publisher_class.new(Repos.rubygems)
          publisher.publish(gem_file)
          return if publisher.successful_repos.include?("rubygems")

          raise "Publish to rubygems.org failed — check output above"
        end

        def gem_file
          file = Dir.glob(gem_file_glob).max_by { |candidate| File.mtime(candidate) }
          raise "No .gem file found — run gem build first" unless file

          file
        end
      end
    end
  end
end
