# frozen_string_literal: true

require_relative "lib/rake/gem_maintenance/version"

Gem::Specification.new do |spec|
  spec.name = "rake-gem-maintenance"
  spec.version = Rake::GemMaintenance::VERSION
  spec.authors = ["Christophe Broult"]
  spec.email = ["cbroult@yahoo.com"]

  spec.summary = "Rake tasks for gem maintenance: dependency upgrades and version bumps."
  spec.description = "Provides reusable Rake::TaskLib subclasses for upgrading gem dependencies and bumping versions."
  spec.homepage = "https://github.com/cbroult/rake-gem-maintenance"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.7"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = File.join(spec.homepage, "Changelog")
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "bundler-audit"
  spec.add_dependency "gem-release", "~> 2.2"
  spec.add_dependency "rake", ">= 13.0"
end
