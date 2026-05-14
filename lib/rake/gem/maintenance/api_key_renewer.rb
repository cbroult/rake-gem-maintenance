# frozen_string_literal: true

module Rake
  module GemMaintenance
    # Renews a rubygems.org API key using credentials from env vars and
    # persists the new key to Woodpecker CI when server details are available.
    class ApiKeyRenewer
      def initialize(otp_provider:,
                     username_env_var: "RUBYGEMS_USERNAME",
                     password_env_var: "RUBYGEMS_PASSWORD")
        @otp_provider = otp_provider
        @username_env_var = username_env_var
        @password_env_var = password_env_var
      end

      def renew(repository)
        username = env_credential(@username_env_var)
        password = env_credential(@password_env_var)
        return nil if username.nil? || password.nil?

        otp = @otp_provider.otp_for(repository[:name], otp_seed_env_var: repository[:otp_seed_env_var])
        new_key = RubyGemsApiKeyCreator.new(host: repository.fetch(:url, "https://rubygems.org"))
                                       .create(username, password, otp: otp)
        persist_to_woodpecker(new_key)
        new_key
      rescue StandardError
        nil
      end

      private

      def env_credential(var)
        value = ENV.fetch(var, nil)
        value&.empty? ? nil : value
      end

      def persist_to_woodpecker(new_key)
        server = ENV.fetch("WOODPECKER_SERVER", nil)
        token = ENV.fetch("WOODPECKER_TOKEN", nil)
        return unless server && token

        org = ENV.fetch("WOODPECKER_ORG", "cbp-org")
        WoodpeckerSecretStore.new(server: server, org: org, token: token)
                             .store("rubygems_api_key", new_key)
      end
    end
  end
end
