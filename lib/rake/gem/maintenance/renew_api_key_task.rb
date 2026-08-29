# frozen_string_literal: true

require "rake"
require "rake/tasklib"
require_relative "credential_store"

module Rake
  module Gem
    module Maintenance
      # Generates a new rubygems.org API key via the rubygems.org API and stores
      # it in a Woodpecker CI org-level secret. Intended for local developer use only.
      #
      # Creates: <namespace>:renew_api_key
      #
      # Reads WOODPECKER_SERVER and WOODPECKER_TOKEN (or ~/.config/woodpecker/token)
      # from the environment.
      class RenewApiKeyTask < ::Rake::TaskLib
        attr_accessor :namespace_name, :host, :api_key_env_var, :ci_environment,
                      :woodpecker_server, :woodpecker_org, :woodpecker_secret_name,
                      :username_env_var, :password_env_var, :credential_store

        def initialize(namespace_name = :upgrade)
          super()
          apply_defaults(namespace_name)
          define_tasks
        end

        private

        def apply_defaults(namespace_name)
          @namespace_name = namespace_name
          @host = "https://rubygems.org"
          @api_key_env_var = "GEM_HOST_API_KEY"
          @ci_environment = CIEnvironment
          @woodpecker_server = ENV.fetch("WOODPECKER_SERVER", nil)
          @woodpecker_org = ENV.fetch("WOODPECKER_ORG", "cbp-org")
          @woodpecker_secret_name = "rubygems_api_key"
          @username_env_var = "RUBYGEMS_USERNAME"
          @password_env_var = "RUBYGEMS_PASSWORD"
          @credential_store = CredentialStore.new
        end

        def define_tasks
          task_instance = self
          namespace namespace_name do
            desc "Generate a new rubygems.org API key and store it in Woodpecker CI"
            task(:renew_api_key) { task_instance.send(:run_renewal) }
          end
        end

        def run_renewal
          credential_store.apply_to_env(username_env_var: username_env_var, api_key_env_var: api_key_env_var)
          abort_if_ci
          username, password = prompt_credentials
          prompt_otp_seed_if_missing
          api_key = generate_api_key(username, password)
          save_and_distribute(username, api_key)
        end

        def generate_api_key(username, password)
          otp = OtpProvider.new.otp_for("rubygems", otp_seed_env_var: "RUBYGEMS_OTP_SEED")
          RubyGemsApiKeyCreator.new(host: host).create(username, password, otp: otp)
        end

        def save_and_distribute(username, api_key)
          puts "\n[INFO] New API key generated."
          credential_store.update(username: username, api_key: api_key, api_key_env_var: api_key_env_var)
          store_in_woodpecker(api_key)
        end

        def abort_if_ci
          return unless ci_environment.ci?

          missing = [username_env_var, password_env_var].select { |v| env_credential(v).nil? }
          return if missing.empty?

          abort "[ERROR] Set #{missing.join(' and ')} CI secrets to run renewal unattended."
        end

        def prompt_otp_seed_if_missing
          return if (seed = ENV.fetch("RUBYGEMS_OTP_SEED", nil)) && !seed.empty?

          print "rubygems.org OTP seed (TOTP secret, not a code): "
          seed = $stdin.gets&.chomp
          ENV["RUBYGEMS_OTP_SEED"] = seed if seed && !seed.empty?
        end

        def prompt_credentials
          username = env_credential(username_env_var) || prompt_username
          password = env_credential(password_env_var) || read_password("rubygems.org password: ")
          [username, password]
        end

        def env_credential(env_var)
          value = ENV.fetch(env_var, nil)
          value && value.empty? ? nil : value
        end

        def prompt_username
          print "rubygems.org username: "
          value = $stdin.gets&.chomp
          abort "[ERROR] No username provided." if value.nil? || value.empty?
          value
        end

        def read_password(prompt)
          require "io/console"
          print prompt
          password = $stdin.noecho(&:gets)&.chomp
          puts
          password
        rescue LoadError
          print prompt
          $stdin.gets&.chomp
        end

        def store_in_woodpecker(api_key)
          unless woodpecker_server
            puts "[INFO] Set WOODPECKER_SERVER to auto-store the key in Woodpecker CI."
            puts "[INFO] New API key (store as secret '#{woodpecker_secret_name}'): #{api_key}"
            return
          end

          token = read_woodpecker_token
          abort "[ERROR] No Woodpecker token. Set WOODPECKER_TOKEN or run woodpecker-cli setup." unless token

          WoodpeckerSecretStore.new(server: woodpecker_server, org: woodpecker_org, token: token)
                               .store(woodpecker_secret_name, api_key)
          puts "[SUCCESS] API key stored in Woodpecker secret '#{woodpecker_secret_name}'."
        end

        def read_woodpecker_token
          ENV.fetch("WOODPECKER_TOKEN", nil) ||
            File.read(File.expand_path("~/.config/woodpecker/token")).strip
        rescue Errno::ENOENT
          nil
        end
      end
    end
  end
end
