# frozen_string_literal: true

module Rake
  module Gem
    module Maintenance
      # Creates a new scoped API key on rubygems.org via the v2 API.
      # Handles OTP header injection and maps HTTP error codes to actionable messages.
      class RubyGemsApiKeyCreator
        def initialize(host: "https://rubygems.org")
          @host = host
        end

        def create(username, password, otp: nil)
          require "net/http"

          request = build_request(username, password, otp)
          response = http_client.request(request)
          parse_response(response)
        end

        private

        def build_request(username, password, otp)
          uri = URI("#{@host}/api/v1/api_key")
          key_name = "rake-gem-maintenance-ci-#{Time.now.strftime('%Y%m%d')}"
          req = Net::HTTP::Post.new(uri)
          req.basic_auth(username, password)
          req["OTP"] = otp if otp
          req["Content-Type"] = "application/x-www-form-urlencoded"
          req.body = "name=#{key_name}&push_rubygem=true"
          req
        end

        def http_client
          uri = URI(@host)
          http = Net::HTTP.new(uri.hostname, uri.port)
          http.use_ssl = true
          http
        end

        def parse_response(response)
          case response.code.to_i
          when 200, 201 then response.body.strip
          when 401 then abort "[ERROR] Invalid credentials for #{@host}."
          when 403 then abort "[ERROR] Forbidden. Check your MFA settings on #{@host}."
          when 449 then abort "[ERROR] OTP required by #{@host}. Set RUBYGEMS_OTP_SEED and retry."
          else abort "[ERROR] #{@host} returned #{response.code}: #{response.body.strip}"
          end
        end
      end
    end
  end
end
