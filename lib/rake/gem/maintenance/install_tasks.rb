# frozen_string_literal: true

require_relative "../maintenance"

Rake::GemMaintenance::UpgradeTask.new
Rake::GemMaintenance::VersionBumpTask.new
