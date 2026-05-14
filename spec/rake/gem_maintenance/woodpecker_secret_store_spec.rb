# frozen_string_literal: true

RSpec.describe Rake::GemMaintenance::WoodpeckerSecretStore do
  subject(:store) do
    described_class.new(server: "https://ci.example.internal", org: "my-org", token: "tok")
  end

  let(:http) { instance_double(Net::HTTP) }
  let(:success_response) { instance_double(Net::HTTPSuccess, is_a?: true, body: "{}") }
  let(:orgs_response) do
    instance_double(Net::HTTPSuccess, is_a?: true,
                                      body: '[{"id":5,"name":"my-org"}]')
  end

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive_messages("use_ssl=": nil, "verify_mode=": nil)
  end

  describe "#store" do
    context "when the secret does not exist yet" do
      let(:secrets_response) { instance_double(Net::HTTPSuccess, is_a?: true, body: "[]") }
      let(:post_req) do
        instance_double(Net::HTTP::Post).tap do |r|
          allow(r).to receive(:[]=)
          allow(r).to receive(:body=)
        end
      end

      before do
        allow(Net::HTTP::Post).to receive(:new).and_return(post_req)
        allow(http).to receive(:request).and_return(orgs_response, secrets_response, success_response)
      end

      it "POSTs to the secrets endpoint" do
        store.store("my_secret", "key-value")
        expect(Net::HTTP::Post).to have_received(:new)
          .with(URI("https://ci.example.internal/api/orgs/5/secrets"))
      end
    end

    context "when the org is not found" do
      before do
        allow(http).to receive(:request)
          .and_return(instance_double(Net::HTTPSuccess, is_a?: true, body: "[]"))
      end

      it "aborts with an org not found message" do
        expect { store.store("my_secret", "key-value") }
          .to output(/my-org/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "when the secret already exists" do
      let(:secrets_response) do
        instance_double(Net::HTTPSuccess, is_a?: true,
                                          body: '[{"id":9,"name":"my_secret"}]')
      end
      let(:patch_req) do
        instance_double(Net::HTTP::Patch).tap do |r|
          allow(r).to receive(:[]=)
          allow(r).to receive(:body=)
        end
      end

      before do
        allow(Net::HTTP::Patch).to receive(:new).and_return(patch_req)
        allow(http).to receive(:request).and_return(orgs_response, secrets_response, success_response)
      end

      it "PATCHes to the named secret endpoint" do
        store.store("my_secret", "key-value")
        expect(Net::HTTP::Patch).to have_received(:new)
          .with(URI("https://ci.example.internal/api/orgs/5/secrets/my_secret"))
      end
    end
  end
end
