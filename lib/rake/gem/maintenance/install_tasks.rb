# frozen_string_literal: true

require_relative "../maintenance"

Rake::Gem::Maintenance::Repos.rubygems_api_key_env_var = "GEM_HOST_API_KEY"
Rake::Gem::Maintenance::Repos.rubygems_otp_seed_env_var = "RUBYGEMS_OTP_SEED"

Rake::Gem::Maintenance::UpgradeTask.new { |t| t.release_task = :"publish:release" }
Rake::Gem::Maintenance::VersionBumpTask.new
Rake::Gem::Maintenance::RubygemsPublishTask.new

Rake::Gem::Maintenance::CredentialStore.new.apply_to_env(
  username_env_var: "RUBYGEMS_USERNAME",
  api_key_env_var: "GEM_HOST_API_KEY"
)
