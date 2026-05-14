# frozen_string_literal: true

require_relative "../maintenance"

Rake::GemMaintenance::Repos.rubygems_api_key_env_var = "GEM_HOST_API_KEY"
Rake::GemMaintenance::Repos.rubygems_otp_seed_env_var = "RUBYGEMS_OTP_SEED"

Rake::GemMaintenance::UpgradeTask.new
Rake::GemMaintenance::VersionBumpTask.new

Rake::GemMaintenance::CredentialStore.new.apply_to_env(
  username_env_var: "RUBYGEMS_USERNAME",
  api_key_env_var: "GEM_HOST_API_KEY"
)
