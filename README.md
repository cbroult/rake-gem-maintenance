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

## Automated Publishing to rubygems.org

The `upgrade:auto` task pushes the gem to rubygems.org automatically. It requires these
environment variables:

| Variable | Purpose | Stored locally? |
|---|---|---|
| `GEM_HOST_API_KEY` | rubygems.org API key | Yes (auto-saved after renewal) |
| `RUBYGEMS_OTP_SEED` | TOTP seed for 2FA | Yes (auto-saved on first run) |
| `RUBYGEMS_USERNAME` | rubygems.org username | Yes (auto-saved on first run) |
| `RUBYGEMS_PASSWORD` | rubygems.org password | **Never** (prompted each renewal) |

### First-run setup

Run the renewal task once to generate and save credentials:

```bash
bundle exec rake upgrade:renew_api_key
# Prompts for: username, password, OTP seed (TOTP secret)
# Saves to: ~/.config/rake-gem-maintenance/credentials.yml (chmod 0600)
# Future runs: only password is prompted
```

The credential file (`~/.config/rake-gem-maintenance/credentials.yml` on Linux/Mac,
`%APPDATA%\rake-gem-maintenance\credentials.yml` on Windows) stores username, API key,
and OTP seed — never the password. See the
[credential store feature](features/upgrade_task/credential_store.feature) for the full
automated workflow spec.

### API key renewal

Keys can be renewed automatically (e.g., via a monthly CI cron) or on demand:

```bash
bundle exec rake upgrade:renew_api_key
```

When run in CI with `RUBYGEMS_USERNAME` and `RUBYGEMS_PASSWORD` set as secrets, the task
runs fully unattended. If either is missing, it aborts with an actionable error.

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

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
