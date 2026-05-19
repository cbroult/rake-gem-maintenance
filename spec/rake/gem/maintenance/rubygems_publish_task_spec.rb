# frozen_string_literal: true

RSpec.describe Rake::Gem::Maintenance::RubygemsPublishTask do
  before { Rake::Task.clear }

  describe "with default configuration" do
    before { described_class.new }

    it "defines the publish:rubygems task" do
      expect(Rake::Task.task_defined?("publish:rubygems")).to be true
    end

    it "sets publish:rubygems description" do
      expect(Rake::Task["publish:rubygems"].comment).to include("rubygems.org")
    end
  end

  describe "default attribute values" do
    subject(:task) { described_class.new }

    it "uses *.gem as the default glob" do
      expect(task.gem_file_glob).to eq("*.gem")
    end

    it "uses GemPublisher as the default publisher class" do
      expect(task.gem_publisher_class).to eq(Rake::Gem::Maintenance::GemPublisher)
    end
  end

  describe "with custom configuration" do
    it "allows customizing gem_file_glob" do
      task = described_class.new { |t| t.gem_file_glob = "pkg/*.gem" }
      expect(task.gem_file_glob).to eq("pkg/*.gem")
    end

    it "allows customizing gem_publisher_class" do
      custom_class = Class.new
      task = described_class.new { |t| t.gem_publisher_class = custom_class }
      expect(task.gem_publisher_class).to eq(custom_class)
    end
  end

  describe "#publish_to_rubygems" do
    subject(:task) { described_class.new { |t| t.gem_publisher_class = publisher_class } }

    let(:publisher_class) { class_double(Rake::Gem::Maintenance::GemPublisher, new: publisher) }
    let(:publisher) { instance_double(Rake::Gem::Maintenance::GemPublisher, publish: nil, successful_repos: ["rubygems"]) }

    before do
      allow(Dir).to receive(:glob).with("*.gem").and_return(["my-gem-1.0.0.gem"])
    end

    it "publishes to rubygems.org" do
      task.send(:publish_to_rubygems)
      expect(publisher).to have_received(:publish).with("my-gem-1.0.0.gem")
    end

    context "when publish fails" do
      let(:publisher) { instance_double(Rake::Gem::Maintenance::GemPublisher, publish: nil, successful_repos: []) }

      it "raises an error" do
        expect { task.send(:publish_to_rubygems) }.to raise_error(RuntimeError, /failed/)
      end
    end
  end

  describe "#gem_file" do
    subject(:task) { described_class.new }

    context "when a .gem file exists" do
      before { allow(Dir).to receive(:glob).with("*.gem").and_return(["foo-1.0.0.gem"]) }

      it "returns the gem file path" do
        expect(task.send(:gem_file)).to eq("foo-1.0.0.gem")
      end
    end

    context "when no .gem file exists" do
      before { allow(Dir).to receive(:glob).with("*.gem").and_return([]) }

      it "raises an error" do
        expect { task.send(:gem_file) }.to raise_error(RuntimeError, /No .gem file found/)
      end
    end
  end
end
