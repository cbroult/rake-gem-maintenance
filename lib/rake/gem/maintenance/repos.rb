# frozen_string_literal: true

module Rake
  module GemMaintenance
    # Pre-configured gem repository configurations for common setups.
    #
    # @example Use internal-only repos
    #   Rake::GemMaintenance::UpgradeTask.new do |t|
    #     t.gem_repositories = Rake::GemMaintenance::Repos.internal
    #   end
    #
    # @example Use both rubygems.org and internal repos
    #   Rake::GemMaintenance::UpgradeTask.new do |t|
    #     t.gem_repositories = Rake::GemMaintenance::Repos.all
    #   end
    #
    # @example Reconfigure internal URL
    #   Rake::GemMaintenance::Repos.internal_url = "https://my-internal-gem.example.com"
    module Repos
      @internal_url = "https://gems.cbp-org.internal"
      @rubygems_url = "https://rubygems.org"

      class << self
        attr_accessor :internal_url, :rubygems_url
      end

      # Publish only to internal repository
      # @return [Array<Hash>] repository configuration
      def self.internal
        [{ name: "cbp-org", url: internal_url }]
      end

      # Publish to both rubygems.org and internal repository
      # @return [Array<Hash>] repository configuration
      def self.all
        [
          { name: "rubygems", url: rubygems_url },
          { name: "cbp-org", url: internal_url }
        ]
      end

      # Publish only to rubygems.org (the default)
      # @return [Array<Hash>] repository configuration
      def self.rubygems
        [{ name: "rubygems", url: rubygems_url }]
      end

      # Default configuration: rubygems.org only
      # @return [Array<Hash>] repository configuration
      def self.default
        rubygems
      end
    end
  end
end
