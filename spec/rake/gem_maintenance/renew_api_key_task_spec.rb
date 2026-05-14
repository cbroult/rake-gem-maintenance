# frozen_string_literal: true

RSpec.describe Rake::GemMaintenance::RenewApiKeyTask do
  before { Rake::Task.clear }

  describe "task definition" do
    before { described_class.new }

    it "defines upgrade:renew_api_key" do
      expect(Rake::Task.task_defined?("upgrade:renew_api_key")).to be true
    end

    it "gives the task a description mentioning generate or renew" do
      expect(Rake::Task["upgrade:renew_api_key"].comment).to match(/generate|renew/i)
    end
  end

  describe "with custom namespace" do
    before { described_class.new(:deploy) }

    it "defines the task under the custom namespace" do
      expect(Rake::Task.task_defined?("deploy:renew_api_key")).to be true
    end
  end

  describe "default attributes" do
    subject(:task_lib) { described_class.new }

    it "defaults host to rubygems.org" do
      expect(task_lib.host).to eq("https://rubygems.org")
    end

    it "defaults api_key_env_var to GEM_HOST_API_KEY" do
      expect(task_lib.api_key_env_var).to eq("GEM_HOST_API_KEY")
    end

    it "defaults woodpecker_secret_name to rubygems_api_key" do
      expect(task_lib.woodpecker_secret_name).to eq("rubygems_api_key")
    end

    it "defaults woodpecker_org to cbp-org" do
      expect(task_lib.woodpecker_org).to eq("cbp-org")
    end
  end

  describe "running the task in CI" do
    let(:ci_environment) { double("CIEnvironment", ci?: true) } # rubocop:disable RSpec/VerifiedDoubles

    it "aborts with an actionable error message" do
      task_lib = described_class.new
      task_lib.ci_environment = ci_environment
      expect { Rake::Task["upgrade:renew_api_key"].execute }.to raise_error(SystemExit)
    end

    it "includes the username env var in the error output" do
      task_lib = described_class.new
      task_lib.ci_environment = ci_environment
      task_lib.username_env_var = "MY_RUBYGEMS_USER"
      expect { Rake::Task["upgrade:renew_api_key"].execute }
        .to output(/MY_RUBYGEMS_USER/).to_stderr.and raise_error(SystemExit)
    end
  end

  describe "#store_in_woodpecker (no WOODPECKER_SERVER)" do
    subject(:task_lib) { described_class.new }

    before { task_lib.woodpecker_server = nil }

    it "prints the API key to stdout when woodpecker_server is nil" do
      expect { task_lib.send(:store_in_woodpecker, "abc123") }
        .to output(/abc123/).to_stdout
    end

    it "prints a hint to set WOODPECKER_SERVER" do
      expect { task_lib.send(:store_in_woodpecker, "abc123") }
        .to output(/WOODPECKER_SERVER/).to_stdout
    end
  end

  describe "#read_woodpecker_token" do
    subject(:task_lib) { described_class.new }

    around { |ex| with_env("WOODPECKER_TOKEN" => nil) { ex.run } }

    it "reads token from WOODPECKER_TOKEN env var" do
      with_env("WOODPECKER_TOKEN" => "env-token") do
        expect(task_lib.send(:read_woodpecker_token)).to eq("env-token")
      end
    end

    it "returns nil when token file is absent and env var unset" do
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      expect(task_lib.send(:read_woodpecker_token)).to be_nil
    end
  end

  def with_env(vars)
    saved = vars.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
