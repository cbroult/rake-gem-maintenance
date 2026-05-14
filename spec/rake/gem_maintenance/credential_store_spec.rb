# frozen_string_literal: true

require "tmpdir"

RSpec.describe Rake::GemMaintenance::CredentialStore do
  subject(:store) { described_class.new(path: path) }

  let(:tmpdir) { Dir.mktmpdir }
  let(:path) { File.join(tmpdir, "rake-gem-maintenance", "credentials.yml") }

  after { FileUtils.rm_rf(tmpdir) }

  describe ".default_path" do
    context "when on Unix", skip: Gem.win_platform? do
      it "uses XDG_CONFIG_HOME when set" do
        with_env("XDG_CONFIG_HOME" => tmpdir) do
          expect(described_class.default_path).to eq(
            File.join(tmpdir, "rake-gem-maintenance", "credentials.yml")
          )
        end
      end

      it "falls back to ~/.config when XDG_CONFIG_HOME is unset" do
        with_env("XDG_CONFIG_HOME" => nil) do
          expect(described_class.default_path).to include(".config/rake-gem-maintenance/credentials.yml")
        end
      end
    end
  end

  describe "#read" do
    context "when the file does not exist" do
      it "returns an empty hash" do
        expect(store.read).to eq({})
      end
    end

    context "when the file exists" do
      before do
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, { "username" => "alice", "gem_host_api_key" => "key123" }.to_yaml)
      end

      it "returns credentials with symbolized keys" do
        expect(store.read).to eq({ username: "alice", gem_host_api_key: "key123" })
      end
    end

    context "when the file is unreadable YAML" do
      before do
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, ":")
      end

      it "returns an empty hash" do
        expect(store.read).to eq({})
      end
    end
  end

  describe "#write" do
    it "creates intermediate directories" do
      store.write(username: "alice")
      expect(File.exist?(path)).to be true
    end

    it "round-trips credentials through read" do
      store.write(username: "alice", gem_host_api_key: "key123", rubygems_otp_seed: "SEED")
      expect(store.read).to eq({ username: "alice", gem_host_api_key: "key123", rubygems_otp_seed: "SEED" })
    end

    it "sets file permissions to 0600 on Unix", skip: Gem.win_platform? do
      store.write(username: "alice")
      expect(File.stat(path).mode & 0o777).to eq(0o600)
    end
  end

  describe "#apply_to_env" do
    let(:all_absent) { { "RUBYGEMS_USERNAME" => nil, "GEM_HOST_API_KEY" => nil, "RUBYGEMS_OTP_SEED" => nil } }

    before { store.write(username: "alice", gem_host_api_key: "key123", rubygems_otp_seed: "SEED") }

    it "sets the username env var from stored credentials" do
      with_env(all_absent) do
        store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
        expect(ENV.fetch("RUBYGEMS_USERNAME", nil)).to eq("alice")
      end
    end

    it "sets the api_key env var from stored credentials" do
      with_env(all_absent) do
        store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
        expect(ENV.fetch("GEM_HOST_API_KEY", nil)).to eq("key123")
      end
    end

    it "sets the OTP seed env var from stored credentials" do
      with_env(all_absent) do
        store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
        expect(ENV.fetch("RUBYGEMS_OTP_SEED", nil)).to eq("SEED")
      end
    end

    it "does not overwrite env vars that are already set" do
      store.write(gem_host_api_key: "from-file")
      with_env("GEM_HOST_API_KEY" => "from-env", "RUBYGEMS_USERNAME" => nil) do
        store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY")
        expect(ENV.fetch("GEM_HOST_API_KEY", nil)).to eq("from-env")
      end
    end

    it "is a no-op when the file does not exist" do
      empty_store = described_class.new(path: File.join(tmpdir, "nonexistent", "creds.yml"))
      with_env(all_absent) do
        expect { empty_store.apply_to_env(username_env_var: "RUBYGEMS_USERNAME", api_key_env_var: "GEM_HOST_API_KEY") }
          .not_to(change { ENV.to_h.slice("GEM_HOST_API_KEY", "RUBYGEMS_OTP_SEED", "RUBYGEMS_USERNAME") })
      end
    end
  end

  describe "#update" do
    it "saves username and api_key to the file" do
      with_env("RUBYGEMS_OTP_SEED" => nil) do
        store.update(username: "alice", api_key: "newkey", api_key_env_var: "GEM_HOST_API_KEY")
      end
      expect(store.read).to include(username: "alice", gem_host_api_key: "newkey")
    end

    it "preserves OTP seed from env if present" do
      with_env("RUBYGEMS_OTP_SEED" => "MYSEED") do
        store.update(username: "alice", api_key: "newkey", api_key_env_var: "GEM_HOST_API_KEY")
      end
      expect(store.read[:rubygems_otp_seed]).to eq("MYSEED")
    end

    it "merges with existing credentials" do
      store.write(rubygems_otp_seed: "PREEXISTING")
      with_env("RUBYGEMS_OTP_SEED" => nil) do
        store.update(username: "alice", api_key: "newkey", api_key_env_var: "GEM_HOST_API_KEY")
      end
      expect(store.read[:rubygems_otp_seed]).to eq("PREEXISTING")
    end

    it "sets the api_key env var in the current process" do
      with_env("GEM_HOST_API_KEY" => nil, "RUBYGEMS_OTP_SEED" => nil) do
        store.update(username: "alice", api_key: "newkey", api_key_env_var: "GEM_HOST_API_KEY")
        expect(ENV.fetch("GEM_HOST_API_KEY", nil)).to eq("newkey")
      end
    end
  end

  def with_env(vars)
    saved = save_env(vars.keys)
    apply_env(vars)
    yield
  ensure
    apply_env(saved)
  end

  def save_env(keys)
    keys.to_h { |k| [k, ENV.fetch(k.to_s, nil)] }
  end

  def apply_env(vars)
    vars.each { |k, v| v.nil? ? ENV.delete(k.to_s) : ENV[k.to_s] = v }
  end
end
