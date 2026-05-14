# frozen_string_literal: true

RSpec.describe Rake::GemMaintenance::RubyGemsApiKeyCreator do
  subject(:creator) { described_class.new(host: "https://rubygems.org") }

  let(:http) { instance_double(Net::HTTP) }
  let(:response) { instance_double(Net::HTTPResponse) }
  let(:req) do
    instance_double(Net::HTTP::Post).tap do |r|
      allow(r).to receive_messages(basic_auth: nil, "body=": nil, "[]=": nil)
    end
  end

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP::Post).to receive(:new).and_return(req)
  end

  describe "#create" do
    context "when the API returns 201" do
      before do
        allow(response).to receive_messages(code: "201", body: "  abc123xyz  ")
      end

      it "returns the stripped API key" do
        expect(creator.create("user", "pass")).to eq("abc123xyz")
      end

      it "includes the OTP header when otp is given" do
        creator.create("user", "pass", otp: "123456")
        expect(req).to have_received(:[]=).with("OTP", "123456")
      end

      it "omits the OTP header when otp is nil" do
        creator.create("user", "pass", otp: nil)
        expect(req).not_to have_received(:[]=).with("OTP", anything)
      end
    end

    context "when the API returns 401" do
      before do
        allow(response).to receive_messages(code: "401", body: "Unauthorized")
      end

      it "aborts with an invalid credentials message" do
        expect { creator.create("user", "wrong") }.to raise_error(SystemExit)
      end

      it "mentions invalid credentials in stderr" do
        expect { creator.create("user", "wrong") }
          .to output(/Invalid credentials/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "when the API returns 449" do
      before do
        allow(response).to receive_messages(code: "449", body: "OTP required")
      end

      it "aborts mentioning OTP required" do
        expect { creator.create("user", "pass") }
          .to output(/OTP required/).to_stderr.and raise_error(SystemExit)
      end
    end
  end
end
