# frozen_string_literal: true

require_relative "../gem_maintenance"

Rake::GemMaintenance::UpgradeTask.new
Rake::GemMaintenance::VersionBumpTask.new
