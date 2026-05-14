# frozen_string_literal: true

require "tmpdir"

RSpec.describe Rake::GemMaintenance::CredentialStore do
  subject(:store) { described_class.new(path: creds_path) }

  let(:tmp_dir) { Dir.mktmpdir }
  let(:creds_path) { File.join(tmp_dir, "credentials.yml") }

  after { FileUtils.rm_rf(tmp_dir) }

  describe ".default_path" do
    context "when XDG_CONFIG_HOME is set" do
      around do |example|
        original = ENV.delete("XDG_CONFIG_HOME")
        ENV["XDG_CONFIG_HOME"] = "/custom/config"
        example.run
        ENV["XDG_CONFIG_HOME"] = original
      end

      it "uses XDG_CONFIG_HOME as the base" do
        expect(described_class.default_path).to start_with("/custom/config")
      end
    end

    it "includes the app directory and filename" do
      path = described_class.default_path
      expect(path).to end_with("rake-gem-maintenance/credentials.yml")
    end
  end

  describe "#read" do
    context "when the file does not exist" do
      it "returns an empty hash" do
        expect(store.read).to eq({})
      end
    end

    context "when the file exists with YAML content" do
      before { store.write(gem_host_api_key: "abc", username: "alice") }

      it "returns symbolized keys" do
        expect(store.read).to include(gem_host_api_key: "abc", username: "alice")
      end
    end

    context "when the file is corrupt" do
      before { File.write(creds_path, ":\tbad\tyaml\t:::") }

      it "returns an empty hash" do
        expect(store.read).to eq({})
      end
    end
  end

  describe "#write" do
    it "creates the directory and file" do
      store.write(gem_host_api_key: "key123")
      expect(File.exist?(creds_path)).to be true
    end

    it "persists the given credentials" do
      store.write(gem_host_api_key: "key123", username: "bob")
      expect(store.read).to include(gem_host_api_key: "key123", username: "bob")
    end

    it "sets permissions to 0600 on Unix", unless: Gem.win_platform? do
      store.write(gem_host_api_key: "key123")
      expect(File.stat(creds_path).mode & 0o777).to eq(0o600)
    end

    it "does not store keys with nil values" do
      store.write(gem_host_api_key: "key123")
      expect(store.read).not_to have_key(:rubygems_otp_seed)
    end
  end

  describe "#apply_to_env" do
    before { store.write(username: "stored-user", gem_host_api_key: "stored-key", rubygems_otp_seed: "stored-seed") }

    after do
      %w[RUBYGEMS_USERNAME GEM_HOST_API_KEY RUBYGEMS_OTP_SEED].each { |k| ENV.delete(k) }
    end

    it "sets username from store when env var is absent" do
      ENV.delete("RUBYGEMS_USERNAME")
      store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
      expect(ENV.fetch("RUBYGEMS_USERNAME", nil)).to eq("stored-user")
    end

    it "sets api key from store when env var is absent" do
      ENV.delete("GEM_HOST_API_KEY")
      store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
      expect(ENV.fetch("GEM_HOST_API_KEY", nil)).to eq("stored-key")
    end

    it "sets OTP seed from store when env var is absent" do
      ENV.delete("RUBYGEMS_OTP_SEED")
      store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
      expect(ENV.fetch("RUBYGEMS_OTP_SEED", nil)).to eq("stored-seed")
    end

    it "does not overwrite an existing env var" do
      ENV["GEM_HOST_API_KEY"] = "existing-key"
      store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
      expect(ENV.fetch("GEM_HOST_API_KEY", nil)).to eq("existing-key")
    end

    context "when credential file does not exist" do
      subject(:empty_store) { described_class.new(path: File.join(tmp_dir, "nonexistent.yml")) }

      it "does not raise and leaves env vars unchanged" do
        ENV.delete("GEM_HOST_API_KEY")
        empty_store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
        expect(ENV.fetch("GEM_HOST_API_KEY", nil)).to be_nil
      end
    end
  end

  describe "#update" do
    after do
      %w[GEM_HOST_API_KEY RUBYGEMS_OTP_SEED].each { |k| ENV.delete(k) }
    end

    it "writes username and api key to the file" do
      store.update(username: "alice", api_key: "new-key", api_key_env_var: "GEM_HOST_API_KEY")
      expect(store.read).to include(username: "alice", gem_host_api_key: "new-key")
    end

    it "sets the api_key env var in the current process" do
      store.update(username: "alice", api_key: "new-key", api_key_env_var: "GEM_HOST_API_KEY")
      expect(ENV.fetch("GEM_HOST_API_KEY", nil)).to eq("new-key")
    end

    it "persists RUBYGEMS_OTP_SEED from env when present" do
      ENV["RUBYGEMS_OTP_SEED"] = "my-seed"
      store.update(username: "alice", api_key: "new-key", api_key_env_var: "GEM_HOST_API_KEY")
      expect(store.read).to include(rubygems_otp_seed: "my-seed")
    end

    it "does not write rubygems_otp_seed when env var is absent" do
      ENV.delete("RUBYGEMS_OTP_SEED")
      store.update(username: "alice", api_key: "new-key", api_key_env_var: "GEM_HOST_API_KEY")
      expect(store.read).not_to have_key(:rubygems_otp_seed)
    end

    it "merges with existing stored credentials" do
      store.write(rubygems_otp_seed: "existing-seed")
      store.update(username: "alice", api_key: "new-key", api_key_env_var: "GEM_HOST_API_KEY")
      expect(store.read).to include(rubygems_otp_seed: "existing-seed")
    end
  end
end
