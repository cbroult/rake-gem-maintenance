# frozen_string_literal: true

RSpec.describe Rake::GemMaintenance::VersionBumpTask do
  before do
    Rake::Task.clear
  end

  describe "with default configuration" do
    before { described_class.new }

    it "defines the version:bump task" do
      expect(Rake::Task.task_defined?("version:bump")).to be true
    end

    it "defines the bump alias task" do
      expect(Rake::Task.task_defined?("bump")).to be true
    end

    it "sets version:bump description" do
      expect(Rake::Task["version:bump"].comment).to include("Bump version")
    end

    it "sets bump alias description" do
      expect(Rake::Task["bump"].comment).to eq("Alias for version:bump")
    end
  end

  describe "with custom configuration" do
    it "allows customizing the namespace" do
      described_class.new { |t| t.namespace_name = :ver }

      expect(Rake::Task.task_defined?("ver:bump")).to be true
    end

    it "allows disabling the alias" do
      described_class.new { |t| t.create_alias = false }

      expect(Rake::Task.task_defined?("bump")).to be false
    end

    it "allows customizing the default type" do
      task = described_class.new { |t| t.default_type = "minor" }

      expect(task.default_type).to eq("minor")
    end

    it "allows customizing the commit message template" do
      task = described_class.new { |t| t.commit_message_template = "release: %<version>s" }

      expect(task.commit_message_template).to eq("release: %<version>s")
    end
  end

  describe "#validate_version_type" do
    before { described_class.new }

    it "accepts patch" do
      expect { described_class.new.send(:validate_version_type, "patch") }.not_to raise_error
    end

    it "accepts minor" do
      expect { described_class.new.send(:validate_version_type, "minor") }.not_to raise_error
    end

    it "accepts major" do
      expect { described_class.new.send(:validate_version_type, "major") }.not_to raise_error
    end

    it "rejects invalid types" do
      expect { described_class.new.send(:validate_version_type, "invalid") }.to raise_error(SystemExit)
    end
  end
end
