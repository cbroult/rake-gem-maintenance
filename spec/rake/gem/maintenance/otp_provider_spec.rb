# frozen_string_literal: true

RSpec.describe Rake::Gem::Maintenance::OtpProvider do
  subject(:provider) { described_class.new(ci_environment: ci_environment, input: input) }

  let(:ci_environment) { double("CIEnvironment", ci?: false) } # rubocop:disable RSpec/VerifiedDoubles
  let(:input) { instance_double(IO) }

  # A valid base32 TOTP seed for tests (known value from rotp test vectors)
  let(:totp_seed) { "JBSWY3DPEHPK3PXP" }

  describe "#otp_for" do
    context "when RUBYGEMS_OTP env var is set" do
      around { |ex| with_env("RUBYGEMS_OTP" => "654321") { ex.run } }

      before { allow(input).to receive(:gets) }

      it "returns the env var value" do
        expect(provider.otp_for("rubygems")).to eq("654321")
      end

      it "does not prompt" do
        provider.otp_for("rubygems")
        expect(input).not_to have_received(:gets)
      end

      it "takes priority even in CI" do
        allow(ci_environment).to receive(:ci?).and_return(true)
        expect(provider.otp_for("rubygems")).to eq("654321")
      end
    end

    context "when otp_seed_env_var is provided and env var contains a seed" do
      around { |ex| with_env("MY_OTP_SEED" => totp_seed) { ex.run } }

      before { allow(input).to receive(:gets) }

      it "returns a 6-digit OTP code" do
        result = provider.otp_for("rubygems", otp_seed_env_var: "MY_OTP_SEED")
        expect(result).to match(/\A\d{6}\z/)
      end

      it "does not prompt" do
        provider.otp_for("rubygems", otp_seed_env_var: "MY_OTP_SEED")
        expect(input).not_to have_received(:gets)
      end

      it "generates a code even in CI" do
        allow(ci_environment).to receive(:ci?).and_return(true)
        result = provider.otp_for("rubygems", otp_seed_env_var: "MY_OTP_SEED")
        expect(result).to match(/\A\d{6}\z/)
      end
    end

    context "when otp_seed_env_var is provided but env var is not set" do
      around { |ex| with_env("MISSING_SEED" => nil) { ex.run } }

      it "falls through to CI guard or interactive prompt" do
        allow(input).to receive(:gets).and_return("123456\n")
        expect(provider.otp_for("rubygems", otp_seed_env_var: "MISSING_SEED")).to eq("123456")
      end
    end

    context "when running in CI with no OTP source" do
      before do
        allow(ci_environment).to receive(:ci?).and_return(true)
        allow(input).to receive(:gets)
      end

      around { |ex| with_env("RUBYGEMS_OTP" => nil) { ex.run } }

      it "returns nil" do
        expect(provider.otp_for("rubygems")).to be_nil
      end

      it "does not prompt" do
        provider.otp_for("rubygems")
        expect(input).not_to have_received(:gets)
      end
    end

    context "when RUBYGEMS_OTP env var is set to empty string" do
      around { |ex| with_env("RUBYGEMS_OTP" => "") { ex.run } }

      it "falls through to interactive prompt" do
        allow(input).to receive(:gets).and_return("123456\n")
        expect(provider.otp_for("rubygems")).to eq("123456")
      end
    end

    context "when no OTP source is configured (local, interactive)" do
      around { |ex| with_env("RUBYGEMS_OTP" => nil) { ex.run } }

      it "includes the repository name in the prompt" do
        allow(input).to receive(:gets).and_return("000000\n")
        expect { provider.otp_for("my-repo") }.to output(/my-repo/).to_stdout
      end

      it "returns the user input" do
        allow(input).to receive(:gets).and_return("123456\n")
        expect(provider.otp_for("rubygems")).to eq("123456")
      end

      it "returns nil when user enters blank input" do
        allow(input).to receive(:gets).and_return("\n")
        expect(provider.otp_for("rubygems")).to be_nil
      end

      it "returns nil when gets returns nil (EOF)" do
        allow(input).to receive(:gets).and_return(nil)
        expect(provider.otp_for("rubygems")).to be_nil
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
end
