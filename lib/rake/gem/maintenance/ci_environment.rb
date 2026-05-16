# frozen_string_literal: true

module Rake
  module Gem
    module Maintenance
      # Detects whether the current process is running inside a CI environment.
      module CIEnvironment
        def self.ci?
          ENV["CI"].to_s != ""
        end
      end
    end
  end
end
