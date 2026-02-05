# Rake::GemMaintenance

[![Test rake-gem-maintenance](https://github.com/cbroult/rake-gem-maintenance/actions/workflows/main.yml/badge.svg)](https://github.com/cbroult/rake-gem-maintenance/actions/workflows/main.yml)
[![Dependabot Updates](https://github.com/cbroult/rake-gem-maintenance/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/cbroult/rake-gem-maintenance/actions/workflows/dependabot/dependabot-updates)

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

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
