# frozen_string_literal: true

require "rake"
require "rake/tasklib"
require_relative "gem_publisher"
require_relative "repos"

module Rake
  module Gem
    module Maintenance
      # Defines the publish:rubygems Rake task for pushing a built .gem to rubygems.org.
      #
      # Expects a .gem file to already exist in the working directory (run gem build first).
      # Uses the GEM_HOST_API_KEY and RUBYGEMS_OTP_SEED env vars configured via Repos.
      class RubygemsPublishTask < ::Rake::TaskLib
        GEM_FILE_GLOB = "*.gem"

        attr_accessor :gem_file_glob, :gem_publisher_class

        def initialize
          super
          @gem_file_glob = GEM_FILE_GLOB
          @gem_publisher_class = GemPublisher

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
          end
        end

        def publish_to_rubygems
          publisher = gem_publisher_class.new(Repos.rubygems)
          publisher.publish(gem_file)
          return if publisher.successful_repos.include?("rubygems")

          raise "Publish to rubygems.org failed — check output above"
        end

        def gem_file
          file = Dir.glob(gem_file_glob).first
          raise "No .gem file found — run gem build first" unless file

          file
        end
      end
    end
  end
end
