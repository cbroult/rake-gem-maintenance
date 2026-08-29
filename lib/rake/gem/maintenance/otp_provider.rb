# frozen_string_literal: true

module Rake
  module Gem
    module Maintenance
      # Resolves a 2FA OTP code for gem push, either from the environment or interactively.
      # Resolution order for otp_for:
      #   1. RUBYGEMS_OTP env var set → use raw code (works in CI and locally)
      #   2. otp_seed_env_var provided and env var set → generate TOTP code (works in CI and locally)
      #   3. CI environment → nil (gate only interactive prompt)
      #   4. Interactive prompt
      class OtpProvider
        def initialize(ci_environment: CIEnvironment, input: $stdin)
          @ci_environment = ci_environment
          @input = input
        end

        def otp_for(repository_name, otp_seed_env_var: nil)
          env_otp = ENV.fetch("RUBYGEMS_OTP", nil)
          return env_otp if env_otp && !env_otp.empty?

          if otp_seed_env_var
            seed = ENV.fetch(otp_seed_env_var, nil)
            return generate_totp(seed) if seed && !seed.empty?
          end

          return nil if @ci_environment.ci?

          prompt_for_otp(repository_name)
        end

        private

        def generate_totp(seed)
          require "rotp"
          ::ROTP::TOTP.new(seed).now
        end

        def prompt_for_otp(repository_name)
          print "Enter OTP for #{repository_name} (blank to skip): "
          value = @input.gets&.chomp
          value && value.empty? ? nil : value
        end
      end
    end
  end
end
