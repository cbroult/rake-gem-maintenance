# frozen_string_literal: true

RSpec.describe Rake::GemMaintenance::UpgradeTask do
  before do
    Rake::Task.clear
  end

  describe "with default configuration" do
    before { described_class.new }

    it "defines the upgrade task" do
      expect(Rake::Task.task_defined?("upgrade")).to be true
    end

    it "defines upgrade:auto" do
      expect(Rake::Task.task_defined?("upgrade:auto")).to be true
    end

    it "defines upgrade:branch" do
      expect(Rake::Task.task_defined?("upgrade:branch")).to be true
    end

    it "defines upgrade:gems" do
      expect(Rake::Task.task_defined?("upgrade:gems")).to be true
    end

    it "defines upgrade:commit" do
      expect(Rake::Task.task_defined?("upgrade:commit")).to be true
    end

    it "defines upgrade:push" do
      expect(Rake::Task.task_defined?("upgrade:push")).to be true
    end

    it "sets upgrade:auto pipeline with default tasks" do
      prerequisites = Rake::Task["upgrade:auto"].prerequisites
      expect(prerequisites).to eq(%w[branch gems verify commit version:bump release push])
    end
  end

  describe "with custom configuration" do
    it "defines the top-level task with custom name" do
      described_class.new(:deps)

      expect(Rake::Task.task_defined?("deps")).to be true
    end

    it "defines the namespaced tasks with custom name" do
      described_class.new(:deps)

      expect(Rake::Task.task_defined?("deps:auto")).to be true
    end

    it "allows customizing the main branch" do
      task = described_class.new { |t| t.main_branch = "develop" }

      expect(task.main_branch).to eq("develop")
    end

    it "allows customizing the upgrade branch" do
      task = described_class.new { |t| t.upgrade_branch = "chore/deps" }

      expect(task.upgrade_branch).to eq("chore/deps")
    end

    it "allows customizing the commit message" do
      task = described_class.new { |t| t.commit_message = "chore: update deps" }

      expect(task.commit_message).to eq("chore: update deps")
    end

    it "allows customizing files to commit" do
      task = described_class.new { |t| t.files_to_commit = %w[Gemfile Gemfile.lock yarn.lock] }

      expect(task.files_to_commit).to eq(%w[Gemfile Gemfile.lock yarn.lock])
    end

    it "allows customizing the verification task" do
      described_class.new { |t| t.verification_task = :test }

      prerequisites = Rake::Task["upgrade:auto"].prerequisites
      expect(prerequisites).to include("test")
    end

    it "allows customizing the auto pipeline" do
      described_class.new { |t| t.auto_pipeline = %i[branch gems commit push] }

      prerequisites = Rake::Task["upgrade:auto"].prerequisites
      expect(prerequisites).to eq(%w[branch gems commit push])
    end

    it "allows disabling rubygems update" do
      task = described_class.new { |t| t.update_rubygems = false }

      expect(task.update_rubygems).to be false
    end

    it "allows disabling bundle audit" do
      task = described_class.new { |t| t.run_bundle_audit = false }

      expect(task.run_bundle_audit).to be false
    end
  end

  describe "task descriptions" do
    before { described_class.new }

    it "sets upgrade description" do
      expect(Rake::Task["upgrade"].comment).to eq("Alias for upgrade:auto")
    end

    it "sets upgrade:auto description" do
      expect(Rake::Task["upgrade:auto"].comment).to include("Update gems automatically")
    end

    it "sets upgrade:branch description" do
      expect(Rake::Task["upgrade:branch"].comment).to include("Create a branch")
    end

    it "sets upgrade:gems description" do
      expect(Rake::Task["upgrade:gems"].comment).to include("Upgrade gems")
    end

    it "sets upgrade:commit description" do
      expect(Rake::Task["upgrade:commit"].comment).to include("Commit")
    end

    it "sets upgrade:push description" do
      expect(Rake::Task["upgrade:push"].comment).to include("Push")
    end
  end
end
