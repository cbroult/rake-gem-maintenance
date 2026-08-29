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

    it "defines the publish:release task" do
      expect(Rake::Task.task_defined?("publish:release")).to be true
    end

    it "builds, tags, pushes git and publishes with OTP support" do
      expect(Rake::Task["publish:release"].prerequisites)
        .to eq(%w[build release:guard_clean release:source_control_push publish:rubygems])
    end
  end

  describe "default attribute values" do
    subject(:task) { described_class.new }

    it "looks for built gems in pkg first" do
      expect(task.gem_file_glob).to eq("{pkg/*.gem,*.gem}")
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
      allow(Dir).to receive(:glob).with("{pkg/*.gem,*.gem}").and_return(["my-gem-1.0.0.gem"])
      allow(File).to receive(:mtime).and_return(Time.now)
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
      before do
        allow(Dir).to receive(:glob).with("{pkg/*.gem,*.gem}").and_return(["foo-1.0.0.gem"])
        allow(File).to receive(:mtime).and_return(Time.now)
      end

      it "returns the gem file path" do
        expect(task.send(:gem_file)).to eq("foo-1.0.0.gem")
      end
    end

    context "when several built gems exist" do
      before do
        allow(Dir).to receive(:glob).with("{pkg/*.gem,*.gem}")
                                    .and_return(["pkg/foo-1.0.0.gem", "pkg/foo-1.0.1.gem"])
        allow(File).to receive(:mtime).with("pkg/foo-1.0.0.gem").and_return(Time.now - 60)
        allow(File).to receive(:mtime).with("pkg/foo-1.0.1.gem").and_return(Time.now)
      end

      it "returns the most recently built one" do
        expect(task.send(:gem_file)).to eq("pkg/foo-1.0.1.gem")
      end
    end

    context "when no .gem file exists" do
      before { allow(Dir).to receive(:glob).with("{pkg/*.gem,*.gem}").and_return([]) }

      it "raises an error" do
        expect { task.send(:gem_file) }.to raise_error(RuntimeError, /No .gem file found/)
      end
    end
  end
end
