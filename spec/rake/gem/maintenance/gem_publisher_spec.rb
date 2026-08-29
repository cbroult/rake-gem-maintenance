# frozen_string_literal: true

RSpec.describe Rake::Gem::Maintenance::GemPublisher do
  subject(:publisher) { described_class.new(repositories, otp_provider: otp_provider) }

  let(:otp_provider) { instance_double(Rake::Gem::Maintenance::OtpProvider, otp_for: nil) }
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

  describe "#versions_on_repository" do
    let(:repository) { { name: "rubygems", url: "https://rubygems.org" } }
    let(:uri) { instance_double(URI::HTTPS) }

    before { allow(URI).to receive(:parse).with(versions_url).and_return(uri) }

    context "when the repository answers with the published versions" do
      before { allow(uri).to receive(:read).and_return('[{"number":"1.1.0"},{"number":"1.0.0"}]') }

      it "returns the version numbers" do
        expect(publisher.versions_on_repository("my-gem", repository)).to eq(%w[1.1.0 1.0.0])
      end

      it "requests JSON with an Accept header" do
        publisher.versions_on_repository("my-gem", repository)
        expect(uri).to have_received(:read).with("Accept" => "application/json")
      end

      it "does not record the repository as failed" do
        publisher.versions_on_repository("my-gem", repository)
        expect(publisher.failed_repositories).to be_empty
      end
    end

    context "when the gem is not published on the repository" do
      before { allow(uri).to receive(:read).and_raise(http_error(["404", "Not Found"])) }

      it "returns no versions" do
        expect(publisher.versions_on_repository("my-gem", repository)).to be_empty
      end

      it "keeps the repository available" do
        publisher.versions_on_repository("my-gem", repository)
        expect(publisher.failed_repositories).to be_empty
      end
    end

    context "when the repository fails" do
      before { allow(uri).to receive(:read).and_raise(SocketError, "getaddrinfo failed") }

      it "records the repository as failed" do
        publisher.versions_on_repository("my-gem", repository)
        expect(publisher.failed_repositories).to eq(["rubygems"])
      end

      it "records a warning" do
        publisher.versions_on_repository("my-gem", repository)
        expect(publisher.warnings.first[:error]).to include("Cannot fetch versions")
      end
    end

    context "when the repository answers with a server error" do
      before { allow(uri).to receive(:read).and_raise(http_error(["500", "Internal Server Error"])) }

      it "records the repository as failed" do
        publisher.versions_on_repository("my-gem", repository)
        expect(publisher.failed_repositories).to eq(["rubygems"])
      end
    end

    def versions_url
      "https://rubygems.org/api/v1/versions/my-gem.json"
    end

    def http_error(status)
      io = StringIO.new("")
      io.extend(OpenURI::Meta)
      io.status = status
      OpenURI::HTTPError.new(status.join(" "), io)
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
