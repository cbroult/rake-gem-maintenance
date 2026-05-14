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
    # @example Use local geminabox only
    #   Rake::GemMaintenance::GeminaboxUpgradeTask.new
    #
    # @example Dual publishing: geminabox + rubygems.org
    #   Rake::GemMaintenance::UpgradeTask.new do |t|
    #     t.gem_repositories = Rake::GemMaintenance::Repos.geminabox +
    #                          Rake::GemMaintenance::Repos.rubygems
    #   end
    #
    # @example Reconfigure internal URL
    #   Rake::GemMaintenance::Repos.internal_url = "https://my-internal-gem.example.com"
    #
    # @example Configure API key and TOTP seed env vars
    #   Rake::GemMaintenance::Repos.rubygems_api_key_env_var = "GEM_HOST_API_KEY"
    #   Rake::GemMaintenance::Repos.rubygems_otp_seed_env_var = "RUBYGEMS_OTP_SEED"
    #   Rake::GemMaintenance::Repos.geminabox_url = "http://localhost:9292"
    module Repos
      @internal_url = "https://gems.cbp-org.internal"
      @rubygems_url = "https://rubygems.org"
      @geminabox_url = "http://localhost:9292"

      @rubygems_api_key_env_var = nil
      @internal_api_key_env_var = nil
      @geminabox_api_key_env_var = nil

      @rubygems_otp_seed_env_var = nil
      @internal_otp_seed_env_var = nil
      @geminabox_otp_seed_env_var = nil

      class << self
        attr_accessor :internal_url, :rubygems_url, :geminabox_url,
                      :rubygems_api_key_env_var, :internal_api_key_env_var,
                      :geminabox_api_key_env_var,
                      :rubygems_otp_seed_env_var, :internal_otp_seed_env_var,
                      :geminabox_otp_seed_env_var
      end

      # Publish only to internal repository
      # @return [Array<Hash>] repository configuration
      def self.internal
        base = { name: "cbp-org", url: internal_url }
        base[:api_key_env_var] = internal_api_key_env_var if internal_api_key_env_var
        base[:otp_seed_env_var] = internal_otp_seed_env_var if internal_otp_seed_env_var
        [base]
      end

      # Publish to both rubygems.org and internal repository
      # @return [Array<Hash>] repository configuration
      def self.all
        rubygems + internal
      end

      # Publish only to rubygems.org (the default)
      # @return [Array<Hash>] repository configuration
      def self.rubygems
        base = { name: "rubygems", url: rubygems_url }
        base[:api_key_env_var] = rubygems_api_key_env_var if rubygems_api_key_env_var
        base[:otp_seed_env_var] = rubygems_otp_seed_env_var if rubygems_otp_seed_env_var
        [base]
      end

      # Publish only to a local geminabox instance
      # @return [Array<Hash>] repository configuration
      def self.geminabox
        base = { name: "geminabox", url: geminabox_url }
        base[:api_key_env_var] = geminabox_api_key_env_var if geminabox_api_key_env_var
        base[:otp_seed_env_var] = geminabox_otp_seed_env_var if geminabox_otp_seed_env_var
        [base]
      end

      # Default configuration: rubygems.org only
      # @return [Array<Hash>] repository configuration
      def self.default
        rubygems
      end
    end
  end
end
