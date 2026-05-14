# frozen_string_literal: true

RSpec.describe Rake::GemMaintenance::GemPublisher do
  subject(:publisher) { described_class.new(repositories, otp_provider: otp_provider) }

  let(:otp_provider) { instance_double(Rake::GemMaintenance::OtpProvider, otp_for: nil) }
  let(:repositories) { [{ name: "rubygems", url: "https://rubygems.org" }] }
  let(:gem_file) { "my-gem-1.0.0.gem" }

  describe "#initialize" do
    it "accepts repositories as positional arg (backward compatible)" do
      repos = [{ name: "test", url: "https://example.com" }]
      expect(described_class.new(repos).repositories).to eq(repos)
    end

    it "uses default repositories when none given" do
      expect(described_class.new.repositories).to eq([{ name: "rubygems", url: "https://rubygems.org" }])
    end
  end

  describe "#publish" do
    let(:pub) { described_class.new(repositories, otp_provider: otp_provider) }
    let(:ok_status) { instance_double(Process::Status, success?: true) }

    before { allow(Open3).to receive(:capture2e).and_return(["", ok_status]) }

    it "calls gem push with the repository host" do
      pub.publish(gem_file)
      expect(Open3).to have_received(:capture2e).with({}, "gem push #{gem_file} --host https://rubygems.org")
    end

    context "when OTP provider returns a code" do
      before do
        allow(otp_provider).to receive(:otp_for)
          .with("rubygems", otp_seed_env_var: nil).and_return("123456")
      end

      it "appends --otp to the command" do
        pub.publish(gem_file)
        expect(Open3).to have_received(:capture2e)
          .with({}, "gem push #{gem_file} --host https://rubygems.org --otp 123456")
      end
    end

    context "when repository has otp_seed_env_var configured" do
      let(:repositories) do
        [{ name: "rubygems", url: "https://rubygems.org", otp_seed_env_var: "MY_OTP_SEED" }]
      end

      before do
        allow(otp_provider).to receive(:otp_for)
          .with("rubygems", otp_seed_env_var: "MY_OTP_SEED").and_return("999888")
      end

      it "passes otp_seed_env_var to the provider and appends --otp" do
        pub.publish(gem_file)
        expect(Open3).to have_received(:capture2e)
          .with({}, "gem push #{gem_file} --host https://rubygems.org --otp 999888")
      end
    end

    context "when repository has api_key_env_var configured" do
      let(:repositories) { [{ name: "rubygems", url: "https://rubygems.org", api_key_env_var: "MY_GEM_KEY" }] }

      around { |ex| with_env("MY_GEM_KEY" => "secret_token") { ex.run } }

      it "injects the API key into the subprocess environment" do
        pub.publish(gem_file)
        expect(Open3).to have_received(:capture2e).with({ "GEM_HOST_API_KEY" => "secret_token" }, anything)
      end
    end

    context "when api_key_env_var env var is not set" do
      let(:repositories) { [{ name: "rubygems", url: "https://rubygems.org", api_key_env_var: "MISSING_KEY" }] }

      around { |ex| with_env("MISSING_KEY" => nil) { ex.run } }

      it "passes an empty env hash" do
        pub.publish(gem_file)
        expect(Open3).to have_received(:capture2e).with({}, anything)
      end
    end

    context "when api_key_env_var env var is empty string" do
      let(:repositories) { [{ name: "rubygems", url: "https://rubygems.org", api_key_env_var: "EMPTY_KEY" }] }

      around { |ex| with_env("EMPTY_KEY" => "") { ex.run } }

      it "passes an empty env hash" do
        pub.publish(gem_file)
        expect(Open3).to have_received(:capture2e).with({}, anything)
      end
    end

    context "when no api_key_env_var on repository" do
      it "passes an empty env hash (unchanged behaviour)" do
        pub.publish(gem_file)
        expect(Open3).to have_received(:capture2e).with({}, anything)
      end
    end
  end

  describe "#successful_repos and #failed_repositories" do
    let(:pub) { described_class.new(repositories, otp_provider: otp_provider) }
    let(:ok_status) { instance_double(Process::Status, success?: true) }

    before { allow(Open3).to receive(:capture2e).and_return(["", ok_status]) }

    it "tracks successful pushes" do
      pub.publish(gem_file)
      expect(pub.successful_repos).to eq(["rubygems"])
    end

    it "does not record failed repositories when push succeeds" do
      pub.publish(gem_file)
      expect(pub.failed_repositories).to be_empty
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
