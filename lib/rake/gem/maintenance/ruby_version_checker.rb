# frozen_string_literal: true

require "net/http"
require "json"

module Rake
  module Gem
    module Maintenance
      # Fetches the latest stable Ruby version and maintained minors from endoflife.date.
      class RubyVersionChecker
        API_URL = "https://endoflife.date/api/ruby.json"

        def latest_stable
          cycles.max_by { |c| ::Gem::Version.new(c[:latest]) }&.fetch(:latest)
        end

        def maintained_minors
          cycles.map { |c| c[:cycle] }.sort_by { |v| ::Gem::Version.new(v) }
        end

        private

        def cycles
          @cycles ||= fetch_cycles
        end

        def fetch_cycles
          response = Net::HTTP.get(URI(API_URL))
          JSON.parse(response, symbolize_names: true).reject { |c| c[:eol] }
        rescue StandardError
          []
        end
      end
    end
  end
end
