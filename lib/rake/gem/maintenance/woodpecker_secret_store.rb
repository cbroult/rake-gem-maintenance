# frozen_string_literal: true

module Rake
  module Gem
    module Maintenance
      # Creates or updates an org-level secret in a Woodpecker CI server.
      # SSL verification is disabled because Woodpecker is typically served
      # on an internal network with a private CA.
      class WoodpeckerSecretStore
        def initialize(server:, org:, token:)
          @server = server
          @org = org
          @token = token
        end

        def store(secret_name, value, events: %w[push tag manual])
          org_id = find_org_id
          abort "[ERROR] Woodpecker org '#{@org}' not found on #{@server}." unless org_id

          if secret_exists?(org_id, secret_name)
            patch("/api/orgs/#{org_id}/secrets/#{secret_name}",
                  { value: value, events: events, images: [] })
          else
            post("/api/orgs/#{org_id}/secrets",
                 { name: secret_name, value: value, events: events, images: [] })
          end
        end

        private

        def find_org_id
          orgs = get("/api/orgs")
          orgs&.find { |o| o["name"] == @org }&.fetch("id", nil)
        end

        def secret_exists?(org_id, secret_name)
          secrets = get("/api/orgs/#{org_id}/secrets")
          secrets&.any? { |s| s["name"] == secret_name }
        end

        def get(path)
          require "json"
          response = request(Net::HTTP::Get, path)
          JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
        end

        def post(path, body)
          request(Net::HTTP::Post, path, body)
        end

        def patch(path, body)
          request(Net::HTTP::Patch, path, body)
        end

        def request(klass, path, body = nil)
          require "net/http"
          require "json"
          require "openssl"

          uri = URI("#{@server}#{path}")
          http.request(build_req(klass, uri, body))
        end

        def http
          uri = URI(@server)
          h = Net::HTTP.new(uri.hostname, uri.port)
          h.use_ssl = (uri.scheme == "https")
          h.verify_mode = OpenSSL::SSL::VERIFY_NONE
          h
        end

        def build_req(klass, uri, body)
          req = klass.new(uri)
          req["Authorization"] = "Bearer #{@token}"
          if body
            req["Content-Type"] = "application/json"
            req.body = JSON.generate(body)
          end
          req
        end

        def build_http(uri)
          http = Net::HTTP.new(uri.hostname, uri.port)
          http.use_ssl = (uri.scheme == "https")
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http
        end
      end
    end
  end
end
