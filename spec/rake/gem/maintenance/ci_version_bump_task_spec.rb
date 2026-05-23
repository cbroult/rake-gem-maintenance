# frozen_string_literal: true

RSpec.describe Rake::Gem::Maintenance::CiVersionBumpTask do
  before { Rake::Task.clear }

  describe "with default configuration" do
    before { described_class.new }

    it "defines the version:ci_bump task" do
      expect(Rake::Task.task_defined?("version:ci_bump")).to be true
    end

    it "sets a description on version:ci_bump" do
      expect(Rake::Task["version:ci_bump"].comment).to include("CI auto-bump")
    end
  end

  describe "default attribute values" do
    subject(:task) { described_class.new }

    it { expect(task.registry_url).to eq("https://rubygems.org") }
    it { expect(task.ca_cert_env).to be_nil }
    it { expect(task.push_token_env).to be_nil }
    it { expect(task.skip_patterns).to include("[skip bump]", "[skip ci]") }
    it { expect(task.push_branch).to eq("main") }
    it { expect(task.git_author_email).to eq("ci@cbp-org.internal") }
    it { expect(task.git_author_name).to eq("CBP-Org-CI") }
  end

  describe "with custom configuration" do
    it "allows customizing the registry URL" do
      task = described_class.new { |t| t.registry_url = "https://gems.example.com" }
      expect(task.registry_url).to eq("https://gems.example.com")
    end

    it "allows setting the CA cert env var" do
      task = described_class.new { |t| t.ca_cert_env = "MY_CA_CERT" }
      expect(task.ca_cert_env).to eq("MY_CA_CERT")
    end

    it "allows setting the push token env var" do
      task = described_class.new { |t| t.push_token_env = "FORGEJO_PUSH_TOKEN" }
      expect(task.push_token_env).to eq("FORGEJO_PUSH_TOKEN")
    end

    it "allows customizing skip patterns" do
      task = described_class.new { |t| t.skip_patterns = ["[no-bump]"] }
      expect(task.skip_patterns).to eq(["[no-bump]"])
    end

    it "allows customizing the push branch" do
      task = described_class.new { |t| t.push_branch = "release" }
      expect(task.push_branch).to eq("release")
    end
  end

  describe "#skip?" do
    subject(:task) { described_class.new }

    it "returns true when HEAD message contains [skip bump]" do
      expect(task.send(:skip?, "[skip bump] some message")).to be true
    end

    it "returns true when HEAD message contains [skip ci]" do
      expect(task.send(:skip?, "chore: release [skip ci]")).to be true
    end

    it "returns false for a normal commit message" do
      expect(task.send(:skip?, "feat: add new feature")).to be false
    end
  end

  describe "#build_cert_store" do
    subject(:task) { described_class.new }

    it "returns an OpenSSL cert store" do
      expect(task.send(:build_cert_store)).to be_a(OpenSSL::X509::Store)
    end

    it "does not raise when ca_cert_env is nil" do
      expect { task.send(:build_cert_store) }.not_to raise_error
    end
  end

  describe "#head_commit_message" do
    let(:task) { described_class.new }
    let(:success_status) { instance_double(Process::Status, success?: true) }
    let(:failure_status) { instance_double(Process::Status, success?: false) }

    it "returns the stripped commit message on success" do
      allow(Open3).to receive(:capture2).with("git log -1 --pretty=%B")
                                        .and_return(["feat: something\n", success_status])
      expect(task.send(:head_commit_message)).to eq("feat: something")
    end

    it "calls abort when git log fails" do
      allow(Open3).to receive(:capture2).with("git log -1 --pretty=%B")
                                        .and_return(["", failure_status])
      allow(task).to receive(:abort)
      task.send(:head_commit_message)
      expect(task).to have_received(:abort).with("auto-bump: git log failed")
    end
  end

  describe "#origin_url" do
    let(:task) { described_class.new }
    let(:success_status) { instance_double(Process::Status, success?: true) }
    let(:failure_status) { instance_double(Process::Status, success?: false) }

    it "returns the stripped remote URL on success" do
      allow(Open3).to receive(:capture2).with("git remote get-url origin")
                                        .and_return(["https://git.example.com/repo\n", success_status])
      expect(task.send(:origin_url)).to eq("https://git.example.com/repo")
    end

    it "calls abort when git remote fails" do
      allow(Open3).to receive(:capture2).with("git remote get-url origin")
                                        .and_return(["", failure_status])
      allow(task).to receive(:abort)
      task.send(:origin_url)
      expect(task).to have_received(:abort).with("auto-bump: could not determine origin URL")
    end
  end

  describe "#head_opts_out?" do
    let(:task) { described_class.new }

    context "when HEAD message contains a skip pattern" do
      before { allow(task).to receive(:head_commit_message).and_return("[skip ci] auto-bump") }

      it "returns true" do
        expect(task.send(:head_opts_out?)).to be true
      end

      it "prints a skip message" do
        expect { task.send(:head_opts_out?) }.to output(/HEAD opts out/).to_stdout
      end
    end

    context "when HEAD message contains no skip pattern" do
      before { allow(task).to receive(:head_commit_message).and_return("feat: new feature") }

      it "returns false" do
        expect(task.send(:head_opts_out?)).to be false
      end
    end
  end

  describe "#current_version" do
    let(:task) { described_class.new }

    before { allow(task).to receive(:version_file).and_return("lib/my_gem/version.rb") }

    it "parses a double-quoted VERSION constant" do
      allow(File).to receive(:read).with("lib/my_gem/version.rb").and_return('  VERSION = "1.2.3"')
      expect(task.send(:current_version)).to eq("1.2.3")
    end

    it "parses a single-quoted VERSION constant" do
      allow(File).to receive(:read).with("lib/my_gem/version.rb").and_return("  VERSION = '0.9.1'")
      expect(task.send(:current_version)).to eq("0.9.1")
    end

    it "calls abort when VERSION cannot be parsed" do
      allow(File).to receive(:read).with("lib/my_gem/version.rb").and_return("no version here")
      allow(task).to receive(:abort)
      task.send(:current_version)
      expect(task).to have_received(:abort).with(match(/could not parse VERSION/))
    end
  end

  describe "#already_published?" do
    let(:task) { described_class.new }

    before do
      allow(task).to receive_messages(gem_name: "my-gem", build_cert_store: OpenSSL::X509::Store.new)
    end

    it "returns true when the registry responds with 2xx" do
      allow(Net::HTTP).to receive(:start).and_return(Net::HTTPOK.new("1.1", "200", "OK"))
      expect(task.send(:already_published?, "1.0.0")).to be true
    end

    it "returns false when the registry responds with 404" do
      allow(Net::HTTP).to receive(:start).and_return(Net::HTTPNotFound.new("1.1", "404", "Not Found"))
      expect(task.send(:already_published?, "1.0.0")).to be false
    end

    it "returns false when the network request raises" do
      allow(Net::HTTP).to receive(:start).and_raise(StandardError, "connection refused")
      expect(task.send(:already_published?, "1.0.0")).to be false
    end
  end

  describe "#authenticated_url" do
    let(:base_url) { "https://git.example.com/repo" }

    context "when push_token_env is nil" do
      subject(:task) { described_class.new }

      it "returns the URL unchanged" do
        expect(task.send(:authenticated_url, base_url)).to eq(base_url)
      end
    end

    context "when push_token_env is set but the env var is absent" do
      subject(:task) { described_class.new { |t| t.push_token_env = "NO_SUCH_VAR" } }

      it "returns the URL unchanged" do
        expect(task.send(:authenticated_url, base_url)).to eq(base_url)
      end
    end

    context "when push_token_env points to a populated env var" do
      subject(:task) { described_class.new { |t| t.push_token_env = "CI_PUSH_TOKEN" } }

      around do |example|
        ENV["CI_PUSH_TOKEN"] = "secret123"
        example.run
        ENV.delete("CI_PUSH_TOKEN")
      end

      it "injects x-access-token credentials into the URL" do
        result = task.send(:authenticated_url, base_url)
        expect(result).to eq("https://x-access-token:secret123@git.example.com/repo")
      end
    end
  end

  describe "#run_ci_bump" do
    let(:task) { described_class.new }

    context "when HEAD opts out" do
      before do
        allow(task).to receive(:head_opts_out?).and_return(true)
        allow(task).to receive(:already_published?)
        allow(task).to receive(:perform_bump)
      end

      it "does not check published status" do
        task.send(:run_ci_bump)
        expect(task).not_to have_received(:already_published?)
      end

      it "does not perform a bump" do
        task.send(:run_ci_bump)
        expect(task).not_to have_received(:perform_bump)
      end
    end

    context "when the current version is already published" do
      before do
        allow(task).to receive_messages(head_opts_out?: false, current_version: "1.0.0")
        allow(task).to receive(:already_published?).with("1.0.0").and_return(true)
        allow(task).to receive(:perform_bump)
      end

      it "calls perform_bump" do
        task.send(:run_ci_bump)
        expect(task).to have_received(:perform_bump).with("1.0.0")
      end
    end

    context "when the current version is not yet published" do
      before do
        allow(task).to receive_messages(head_opts_out?: false, current_version: "1.1.0")
        allow(task).to receive(:already_published?).with("1.1.0").and_return(false)
        allow(task).to receive(:perform_bump)
      end

      it "does not call perform_bump" do
        task.send(:run_ci_bump)
        expect(task).not_to have_received(:perform_bump)
      end

      it "prints a no-action message" do
        expect { task.send(:run_ci_bump) }.to output(/not yet published/).to_stdout
      end
    end
  end

  describe "#perform_bump" do
    let(:task) { described_class.new }

    before do
      allow(task).to receive_messages(version_file: "lib/my_gem/version.rb", current_version: "1.0.1")
      allow(task).to receive(:commit_and_push)
    end

    context "when all commands succeed and version changes" do
      before do
        allow(task).to receive(:system).with("git checkout -- .").and_return(true)
        allow(task).to receive(:system).with(match(/gem bump/)).and_return(true)
      end

      it "calls commit_and_push with the bumped version" do
        task.send(:perform_bump, "1.0.0")
        expect(task).to have_received(:commit_and_push).with("1.0.1")
      end
    end

    context "when git checkout fails" do
      before do
        allow(task).to receive(:system).and_return(true)
        allow(task).to receive(:system).with("git checkout -- .").and_return(false)
        allow(task).to receive(:abort)
      end

      it "calls abort" do
        task.send(:perform_bump, "1.0.0")
        expect(task).to have_received(:abort).with("auto-bump: git checkout failed")
      end
    end

    context "when gem bump command fails" do
      before do
        allow(task).to receive(:system).with("git checkout -- .").and_return(true)
        allow(task).to receive(:system).with(match(/gem bump/)).and_return(false)
        allow(task).to receive(:abort)
      end

      it "calls abort" do
        task.send(:perform_bump, "1.0.0")
        expect(task).to have_received(:abort).with("auto-bump: gem bump failed")
      end
    end

    context "when gem bump does not change the version" do
      before do
        allow(task).to receive_messages(system: true, current_version: "1.0.0")
        allow(task).to receive(:abort)
      end

      it "calls abort" do
        task.send(:perform_bump, "1.0.0")
        expect(task).to have_received(:abort).with("auto-bump: gem bump did not change version")
      end
    end
  end

  describe "#commit_and_push" do
    let(:task) { described_class.new }

    before do
      allow(task).to receive_messages(
        version_file: "lib/my_gem/version.rb",
        origin_url: "https://git.example.com/repo",
        authenticated_url: "https://git.example.com/repo"
      )
    end

    context "when all git commands succeed" do
      before { allow(task).to receive(:system).and_return(true) }

      it "runs git add with the version file" do
        task.send(:commit_and_push, "1.2.3")
        expect(task).to have_received(:system).with("git", any_args, "add", "lib/my_gem/version.rb")
      end

      it "commits with the new version and [skip ci]" do
        task.send(:commit_and_push, "1.2.3")
        expect(task).to have_received(:system)
          .with("git", any_args, "commit", "-m", "chore: auto-bump version to 1.2.3 [skip ci]")
      end

      it "tags the new version" do
        task.send(:commit_and_push, "1.2.3")
        expect(task).to have_received(:system).with("git", "tag", "v1.2.3")
      end

      it "pushes with --tags" do
        task.send(:commit_and_push, "1.2.3")
        expect(task).to have_received(:system).with("git", "push", anything, "HEAD:main", "--tags")
      end
    end

    context "when git add fails" do
      before do
        allow(task).to receive(:system).and_return(true)
        allow(task).to receive(:system).with("git", any_args, "add", anything).and_return(false)
        allow(task).to receive(:abort)
      end

      it "calls abort" do
        task.send(:commit_and_push, "1.2.3")
        expect(task).to have_received(:abort).with("auto-bump: git add failed")
      end
    end

    context "when git tag fails" do
      before do
        allow(task).to receive(:system).and_return(true)
        allow(task).to receive(:system).with("git", "tag", anything).and_return(false)
        allow(task).to receive(:abort)
      end

      it "calls abort" do
        task.send(:commit_and_push, "1.2.3")
        expect(task).to have_received(:abort).with("auto-bump: git tag failed")
      end
    end

    context "when git push fails" do
      before do
        allow(task).to receive(:system).and_return(true)
        allow(task).to receive(:system).with("git", "push", anything, anything, "--tags").and_return(false)
        allow(task).to receive(:abort)
      end

      it "calls abort" do
        task.send(:commit_and_push, "1.2.3")
        expect(task).to have_received(:abort).with("auto-bump: git push failed")
      end
    end
  end
end
