# Rake::Gem::Maintenance

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
require "rake/gem/maintenance/install_tasks"
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
require "rake/gem/maintenance"

Rake::Gem::Maintenance::UpgradeTask.new do |t|
  t.main_branch = "develop"
  t.upgrade_branch = "chore/upgrade-deps"
  t.commit_message = "chore: upgrade dependencies"
end

Rake::Gem::Maintenance::VersionBumpTask.new do |t|
  t.default_type = "minor"
end
```

## Automated Publishing to rubygems.org

### Step 1 — First-time setup (one-off, interactive)

Run the renewal task once on your local machine:

```bash
rake upgrade:renew_api_key
```

It will prompt for three things:

| Prompt | What to enter |
|---|---|
| username | Your rubygems.org username or email |
| password | Your rubygems.org password (never stored) |
| OTP seed | The **base32 secret** from your authenticator app setup — the long code shown when you first enabled MFA, *not* the rotating 6-digit code. Omit (press Enter) if MFA is disabled. |

After answering, the task generates a scoped API key and saves it locally alongside your
username and OTP seed:

```
~/.config/rake-gem-maintenance/credentials.yml   # Linux / Mac  (respects $XDG_CONFIG_HOME)
%APPDATA%\rake-gem-maintenance\credentials.yml   # Windows
```

The file is `0600` (owner-read-only on Unix). The **password is never written to disk**.

### Step 2 — All future local runs are automatic

Any project using `require "rake/gem/maintenance/install_tasks"` automatically reads the
credential file at startup and sets `GEM_HOST_API_KEY` and `RUBYGEMS_OTP_SEED` in the process
environment. Running `rake upgrade` needs no manual credential setup from this point on.

See [features/upgrade_task/credential_store.feature](features/upgrade_task/credential_store.feature)
for the full behaviour specification.

### Step 3 — CI setup (Woodpecker / GitHub Actions)

Set the following as CI secrets:

| Secret / env var | Purpose |
|---|---|
| `RUBYGEMS_USERNAME` | rubygems.org username |
| `RUBYGEMS_PASSWORD` | rubygems.org password |
| `RUBYGEMS_OTP_SEED` | Same base32 seed as above |
| `GEM_HOST_API_KEY` | The API key generated in Step 1 (for the initial push) |

On subsequent runs the key is renewed automatically: when `gem push` returns 401/403, the
publisher transparently calls `upgrade:renew_api_key` and retries. The refreshed key is written
back to the `rubygems_api_key` CI secret (requires `WOODPECKER_TOKEN` + `WOODPECKER_SERVER`
when running under Woodpecker CI).

See [features/upgrade_task/renew_api_key.feature](features/upgrade_task/renew_api_key.feature).

### Custom env var names

```ruby
require "rake/gem/maintenance"

Rake::Gem::Maintenance::Repos.rubygems_api_key_env_var  = "MY_RUBYGEMS_KEY"
Rake::Gem::Maintenance::Repos.rubygems_otp_seed_env_var = "MY_OTP_SEED"

Rake::Gem::Maintenance::UpgradeTask.new
```

See [features/upgrade_task/repos_configuration.feature](features/upgrade_task/repos_configuration.feature)
for all configuration options including geminabox and dual publishing.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
