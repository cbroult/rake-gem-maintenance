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

### Core Classes (lib/rake/gem/maintenance/)

- **UpgradeTask** — Rake::TaskLib subclass defining upgrade:* tasks (branch, gems, commit, push, auto)
  - Default repositories: rubygems.org
- **InternalUpgradeTask** — Rake::TaskLib subclass for internal gems only
  - Default repositories: gems.cbp-org.internal
- **DualUpgradeTask** — Rake::TaskLib subclass for gems published to both rubygems.org and cbp-org
  - Default repositories: both rubygems.org and cbp-org.internal
- **VersionBumpTask** — Rake::TaskLib subclass defining version:bump[type] and bump[type] tasks
- **GemPublisher** — Handles publishing gems to multiple repositories, collecting warnings for failed pushes
- **Repos** — Pre-configured repository sets (internal, all, rubygems, default)

### Entry Points

- `rake/gem/maintenance.rb` — requires all task classes
- `rake/gem/maintenance/install_tasks.rb` — auto-instantiates UpgradeTask and VersionBumpTask with defaults

### Quick Usage

```ruby
# Internal gems only (cbp-org.internal)
Rake::Gem::Maintenance::InternalUpgradeTask.new

# Both repositories
Rake::Gem::Maintenance::DualUpgradeTask.new

# Default (rubygems.org) - can also use Repos module
Rake::Gem::Maintenance::UpgradeTask.new do |t|
  t.gem_repositories = Rake::Gem::Maintenance::Repos.internal  # or Repos.all
end
```

## Repository & CI Workflow

**GitHub** (`github.com/cbroult/rake-gem-maintenance`) is the canonical source.
**Forgejo** (`git.cbp-org.internal/forgejo-admin/rake-gem-maintenance`) is a read-only pull mirror.

- All pull requests go on **GitHub only**. Never open PRs on Forgejo.
- Forgejo mirrors GitHub automatically every 10 minutes — never push to the `forgejo` remote manually.
- **Woodpecker CI** (`ci.cbp-org.internal`) watches Forgejo and runs verify/publish/renew pipelines.
- Local clone only needs the `origin` (GitHub) remote. Remove `forgejo` if present: `git remote remove forgejo`.

## Code Style

- Never add `# rubocop:disable` comments without explicit user permission.

## Commit Conventions

- Use conventional commit format: `type(scope): subject`
- Keep subject line under 50 characters
- Use present tense ("add feature" not "added feature")
