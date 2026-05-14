# frozen_string_literal: true

# ci-publish-rubygems.rb — build and push this gem to rubygems.org
#
# Required env:
#   GEM_HOST_API_KEY    rubygems.org API key   (from Woodpecker secret rubygems_api_key)
#   RUBYGEMS_OTP_SEED   base32 TOTP seed       (from Woodpecker secret rubygems_otp_seed)

$LOAD_PATH.unshift File.join(__dir__, "..", "lib")
require "rake/gem/maintenance"

Rake::GemMaintenance::Repos.rubygems_api_key_env_var = "GEM_HOST_API_KEY"
Rake::GemMaintenance::Repos.rubygems_otp_seed_env_var = "RUBYGEMS_OTP_SEED"

gemspec_file = Dir["*.gemspec"].first
abort "ERROR: No gemspec found in #{Dir.pwd}" unless gemspec_file

system("gem build #{gemspec_file}") or abort "ERROR: gem build failed"

gem_file = Dir["*.gem"].max_by { |f| File.mtime(f) }
abort "ERROR: No .gem file found after build" unless gem_file

puts "Publishing #{gem_file} to rubygems.org..."
publisher = Rake::GemMaintenance::GemPublisher.new(Rake::GemMaintenance::Repos.rubygems)
publisher.publish(gem_file)

abort "ERROR: Failed to publish #{gem_file} to rubygems.org" if publisher.successful_repos.empty?

puts "Published #{gem_file} successfully to: #{publisher.successful_repos.join(', ')}"
