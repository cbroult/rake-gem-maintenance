# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Rake::Gem::Maintenance::RubyVersionUpdater do
  let(:tmpdir) { Dir.mktmpdir }
  let(:checker) do
    instance_double(Rake::Gem::Maintenance::RubyVersionChecker,
                    latest_stable: "4.0.3",
                    maintained_minors: %w[3.3 3.4 4.0])
  end

  after { FileUtils.remove_entry(tmpdir) }

  def ruby_version_file = File.join(tmpdir, ".ruby-version")
  def gemspec_file      = File.join(tmpdir, "test.gemspec")
  def workflow_file     = File.join(tmpdir, "main.yml")
  def woodpecker_file   = File.join(tmpdir, "verify.yml")

  def build_updater(**overrides)
    defaults = {
      ruby_version_file: ruby_version_file,
      gemspec_files: [gemspec_file],
      github_workflow_files: [workflow_file],
      woodpecker_config_files: [woodpecker_file]
    }
    described_class.new(**defaults, **overrides)
  end

  describe "#update" do
    context "when checker has no version info" do
      let(:checker) do
        instance_double(Rake::Gem::Maintenance::RubyVersionChecker,
                        latest_stable: nil, maintained_minors: [])
      end

      it "returns an empty array" do
        expect(build_updater.update(checker: checker)).to eq([])
      end
    end

    describe ".ruby-version" do
      it "creates the file with the latest stable version" do
        build_updater.update(checker: checker)
        expect(File.read(ruby_version_file).strip).to eq("4.0.3")
      end

      it "includes the file in the returned list" do
        expect(build_updater.update(checker: checker)).to include(ruby_version_file)
      end

      it "does not include the file when already up to date" do
        File.write(ruby_version_file, "4.0.3\n")
        expect(build_updater.update(checker: checker)).not_to include(ruby_version_file)
      end
    end

    describe "gemspec required_ruby_version" do
      before { File.write(gemspec_file, 'spec.required_ruby_version = ">= 4.0.1"') }

      it "updates the patch version within the same minor" do
        build_updater.update(checker: checker)
        expect(File.read(gemspec_file)).to include(">= 4.0.3")
      end

      it "does not change the minimum when minor differs" do
        File.write(gemspec_file, 'spec.required_ruby_version = ">= 3.3.7"')
        build_updater.update(checker: checker)
        expect(File.read(gemspec_file)).to include(">= 3.3.7")
      end

      it "includes the gemspec in the returned list when changed" do
        expect(build_updater.update(checker: checker)).to include(gemspec_file)
      end
    end

    describe "GitHub Actions workflow" do
      before { File.write(workflow_file, "ruby-version: [ '3.4', '4.0', 'truffleruby' ]") }

      it "updates the matrix to all maintained minors plus truffleruby" do
        build_updater.update(checker: checker)
        expect(File.read(workflow_file)).to eq(
          "ruby-version: [ '3.3', '3.4', '4.0', 'truffleruby' ]"
        )
      end

      it "includes the workflow in the returned list when changed" do
        expect(build_updater.update(checker: checker)).to include(workflow_file)
      end
    end

    describe "Woodpecker Docker image" do
      before { File.write(woodpecker_file, "image: ruby:4.0.2-alpine") }

      it "updates the image tag to latest stable" do
        build_updater.update(checker: checker)
        expect(File.read(woodpecker_file)).to eq("image: ruby:4.0.3-alpine")
      end

      it "preserves the image suffix" do
        File.write(woodpecker_file, "image: ruby:4.0.2-slim")
        build_updater.update(checker: checker)
        expect(File.read(woodpecker_file)).to eq("image: ruby:4.0.3-slim")
      end

      it "includes the file in the returned list when changed" do
        expect(build_updater.update(checker: checker)).to include(woodpecker_file)
      end

      it "does not include the file when already up to date" do
        File.write(woodpecker_file, "image: ruby:4.0.3-alpine")
        expect(build_updater.update(checker: checker)).not_to include(woodpecker_file)
      end
    end
  end
end
