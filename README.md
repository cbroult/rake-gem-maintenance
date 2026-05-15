# Rake::GemMaintenance

[![Ruby](https://github.com/cbroult/rake-gem-maintenance/actions/workflows/main.yml/badge.svg)](https://github.com/cbroult/rake-gem-maintenance/actions/workflows/main.yml)
[![Dependabot](https://img.shields.io/badge/dependabot-enabled-blue?logo=dependabot)](https://github.com/cbroult/rake-gem-maintenance/network/updates)

Reusable Rake tasks for gem maintenance: dependency upgrades and version bumps.

## Installation

Add to your Gemfile:

```ruby
gem "rake-gem-maintenance"
```

## Quick Start

Add to your Rakefile for default behavior:

```ruby
require "rake/gem_maintenance/install_tasks"
```

This defines:
- `upgrade` / `upgrade:auto` — full upgrade pipeline (branch, update, verify, commit, bump, release, push)
- `upgrade:branch` — create upgrade branch
- `upgrade:gems` — update rubygems, bundler, and all gems
- `upgrade:commit` — commit upgraded Gemfile/Gemfile.lock
- `upgrade:push` — push upgrade branch
- `version:bump[type]` — bump version (patch/minor/major) and update Gemfile.lock
- `bump[type]` — alias for `version:bump`

## Customization

```ruby
require "rake/gem_maintenance"

Rake::GemMaintenance::UpgradeTask.new do |t|
  t.main_branch = "develop"
  t.upgrade_branch = "chore/upgrade-deps"
  t.commit_message = "chore: upgrade dependencies"
end

Rake::GemMaintenance::VersionBumpTask.new do |t|
  t.default_type = "minor"
end
```

## Automated Publishing to rubygems.org

Set two environment variables and `gem push` runs fully unattended — including TOTP 2FA code
generation if your rubygems.org account has MFA enabled.

| Env var | Purpose |
|---|---|
| `GEM_HOST_API_KEY` | rubygems.org API key (scoped to push) |
| `RUBYGEMS_OTP_SEED` | Base32 TOTP seed — auto-generates the 2FA code; omit if MFA is disabled |

### Quick setup

`require "rake/gem_maintenance/install_tasks"` pre-configures both env var names automatically —
no extra Ruby needed. See [features/install_tasks.feature](features/install_tasks.feature) for
the full workflow.

### Custom env var names

```ruby
require "rake/gem/maintenance"

Rake::GemMaintenance::Repos.rubygems_api_key_env_var  = "MY_RUBYGEMS_KEY"
Rake::GemMaintenance::Repos.rubygems_otp_seed_env_var = "MY_OTP_SEED"

Rake::GemMaintenance::UpgradeTask.new
```

See [features/upgrade_task/repos_configuration.feature](features/upgrade_task/repos_configuration.feature)
for all configuration options including geminabox and dual publishing.

### Local credential store

After the first successful `upgrade:renew_api_key` run, the API key and OTP seed are saved to:

```
~/.config/rake-gem-maintenance/credentials.yml   # Linux / Mac  (respects $XDG_CONFIG_HOME)
%APPDATA%\rake-gem-maintenance\credentials.yml   # Windows
```

The file is created with `0600` permissions (owner-read-only on Unix). It stores `username`,
`gem_host_api_key`, and `rubygems_otp_seed` — **never the password**. Any project using
`require "rake/gem_maintenance/install_tasks"` automatically loads the key and OTP seed from
this file at startup, so `gem push` works without any manual env-var setup.

See [features/upgrade_task/credential_store.feature](features/upgrade_task/credential_store.feature)
for the full behaviour specification.

### API key renewal

API keys can be rotated in two ways:

**Automatic** — when `gem push` returns a 401/403, the publisher transparently obtains a new
key using `RUBYGEMS_USERNAME` + `RUBYGEMS_PASSWORD` (+ TOTP from `RUBYGEMS_OTP_SEED` if MFA is
enabled), then retries the push once. No intervention needed.

**On-demand** — run the task explicitly to rotate ahead of expiry:

```bash
rake upgrade:renew_api_key
```

Locally this prompts for credentials interactively. In CI, supply all three env vars for
unattended operation:

| Env var | Purpose |
|---|---|
| `RUBYGEMS_USERNAME` | rubygems.org account username or email |
| `RUBYGEMS_PASSWORD` | rubygems.org account password |
| `RUBYGEMS_OTP_SEED` | Same TOTP seed as above — reused here to authenticate the key-creation request |

The new key is written back to the `GEM_HOST_API_KEY` CI secret automatically (requires
`WOODPECKER_TOKEN` and `WOODPECKER_SERVER` when running under Woodpecker CI).

See [features/upgrade_task/renew_api_key.feature](features/upgrade_task/renew_api_key.feature).

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
