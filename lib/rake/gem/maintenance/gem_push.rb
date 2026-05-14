# frozen_string_literal: true

require "open3"

module Rake
  module GemMaintenance
    # Pushes a single gem file to one repository, retrying with a renewed API key on auth failure.
    class GemPush
      Result = Struct.new(:success, :error)

      def initialize(gem_file, repository, otp_provider)
        @gem_file = gem_file
        @repository = repository
        @otp_provider = otp_provider
      end

      def attempt
        out_err, status = Open3.capture2e(env, command)
        return Result.new(true, nil) if status.success?
        return retry_with_renewed_key if auth_failure?(out_err)

        Result.new(false, out_err)
      end

      private

      def command
        cmd = "gem push #{@gem_file} --host #{@repository[:url]}"
        otp = @otp_provider.otp_for(@repository[:name], otp_seed_env_var: @repository[:otp_seed_env_var])
        cmd += " --otp #{otp}" if otp
        cmd
      end

      def env
        env_var = @repository[:api_key_env_var]
        return {} unless env_var

        key = ENV.fetch(env_var, nil)
        return {} if key.nil? || key.empty?

        { "GEM_HOST_API_KEY" => key }
      end

      def auth_failure?(output)
        output.match?(/unauthorized|api.key|forbidden/i) ||
          output.include?("401") || output.include?("403")
      end

      def retry_with_renewed_key
        new_key = ApiKeyRenewer.new(otp_provider: @otp_provider).renew(@repository)
        return Result.new(false, "Auth failed and renewal credentials unavailable.") unless new_key

        _out_err, status = Open3.capture2e(env.merge("GEM_HOST_API_KEY" => new_key), command)
        if status.success?
          Result.new(true, nil)
        else
          Result.new(false, "Push failed after key renewal.")
        end
      end
    end
  end
end
