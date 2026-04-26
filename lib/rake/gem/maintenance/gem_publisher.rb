# frozen_string_literal: true

require "json"
require "open-uri"

module Rake
  module GemMaintenance
    # Publishes gems to multiple gem repositories, with version checking and warning handling.
    class GemPublisher
      attr_reader :repositories, :warnings, :failed_repositories

      def initialize(repositories = default_repositories)
        @repositories = repositories
        @warnings = []
        @failed_pushes = []
        @failed_repositories = []
        @published_files = []
      end

      def default_repositories
        [{ name: "rubygems", url: "https://rubygems.org" }]
      end

      def publish(gem_file)
        @failed_pushes = []
        @published_files = []
        build_and_push(gem_file)
        print_warnings
      end

      def check_all_repositories(gem_name)
        @failed_repositories = []
        repositories.each do |repo|
          versions_on_repository(gem_name, repo)
        end
      end

      def versions_on_repository(gem_name, repository)
        url = "#{repository[:url]}/api/v1/gems/#{gem_name}.json"
        uri = URI.parse(url)
        response = uri.read(accept: "application/json")
        data = JSON.parse(response)
        data["versions"].map { |v| v["number"] }
      rescue StandardError => e
        @failed_repositories << repository[:name]
        @warnings << { repository: repository[:name], error: "Cannot fetch versions: #{e.message}" }
        []
      end

      def next_version(gem_name, current_version)
        return current_version unless current_version

        ver = Gem::Version.new(current_version)
        loop do
          return ver.to_s unless version_exists_on_all_repos?(gem_name, ver)

          ver = ver.bump
        end
      end

      def available_repositories
        repositories.map { |r| r[:name] } - @failed_repositories
      end

      def any_available?
        @failed_repositories.size < repositories.size
      end

      private

      def build_and_push(gem_file)
        repositories.each do |repo|
          push(gem_file, repository: repo)
        end
      end

      def push(gem_file, repository:)
        cmd = "gem push #{gem_file} --host #{repository[:url]}"
        result = system(cmd)
        @published_files << gem_file if result
      rescue StandardError => e
        @failed_pushes << { repository: repository[:name], error: e.message }
      end

      def version_exists_on_all_repos?(gem_name, version)
        repositories.all? do |repo|
          versions_on_repository(gem_name, repo).include?(version.to_s)
        end
      end

      def print_warnings
        return if @failed_pushes.empty?

        puts "[WARN] The following repositories were unavailable:"
        @failed_pushes.each do |failure|
          puts "  - #{failure[:repository]}: #{failure[:error]}"
        end
        puts "[WARN] Warning: Published to #{@published_files.size} of #{repositories.size} repositories"
      end
    end
  end
end
