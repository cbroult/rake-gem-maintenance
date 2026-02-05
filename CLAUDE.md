# CLAUDE.md

## Project Overview

rake-gem-maintenance is a Ruby gem providing reusable Rake::TaskLib subclasses for gem maintenance workflows: dependency upgrades and version bumps.

## Common Commands

```bash
# Install dependencies
bundle install

# Run all verification (specs + rubocop)
rake

# Run RSpec tests only
rake spec

# Run linter with auto-correct
rake rubocop
```

## Architecture

### Core Classes (lib/rake/gem_maintenance/)

- **UpgradeTask** — Rake::TaskLib subclass defining upgrade:* tasks (branch, gems, commit, push, auto)
- **VersionBumpTask** — Rake::TaskLib subclass defining version:bump[type] and bump[type] tasks

### Entry Points

- `rake/gem_maintenance.rb` — requires both task classes
- `rake/gem_maintenance/install_tasks.rb` — auto-instantiates both with defaults

## Commit Conventions

- Use conventional commit format: `type(scope): subject`
- Keep subject line under 50 characters
- Use present tense ("add feature" not "added feature")
