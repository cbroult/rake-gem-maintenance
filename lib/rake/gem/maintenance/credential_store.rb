# frozen_string_literal: true

require "yaml"
require "fileutils"
require "rubygems"

module Rake
  module GemMaintenance
    # Persists rubygems.org credentials (username, API key, OTP seed) to a local config file.
    class CredentialStore
      def self.default_path
        base = if Gem.win_platform?
                 ENV.fetch("APPDATA", File.expand_path("~"))
               else
                 ENV.fetch("XDG_CONFIG_HOME", File.join(Dir.home, ".config"))
               end
        File.join(base, "rake-gem-maintenance", "credentials.yml")
      end

      def initialize(path: self.class.default_path)
        @path = path
      end

      attr_reader :path

      def read
        return {} unless File.exist?(@path)

        YAML.safe_load_file(@path, symbolize_names: true) || {}
      rescue StandardError
        {}
      end

      def write(credentials)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, credentials.transform_keys(&:to_s).to_yaml)
        File.chmod(0o600, @path) unless Gem.win_platform?
      end

      def apply_to_env(username_env_var:, api_key_env_var:)
        creds = read
        set_env_if_absent(username_env_var, creds[:username])
        set_env_if_absent("RUBYGEMS_OTP_SEED", creds[:rubygems_otp_seed])
        set_env_if_absent(api_key_env_var, creds[:gem_host_api_key])
      end

      def update(username:, api_key:, api_key_env_var:)
        otp_seed = ENV.fetch("RUBYGEMS_OTP_SEED", nil)
        updated = read.merge(username: username, gem_host_api_key: api_key)
        updated[:rubygems_otp_seed] = otp_seed if otp_seed && !otp_seed.empty?
        write(updated)
        ENV[api_key_env_var] = api_key
      end

      private

      def set_env_if_absent(env_var, value)
        return unless value && !value.empty?
        return if (existing = ENV.fetch(env_var, nil)) && !existing.empty?

        ENV[env_var] = value
      end
    end
  end
end
