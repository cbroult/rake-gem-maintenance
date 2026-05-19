# frozen_string_literal: true

RSpec.describe Rake::Gem::Maintenance::RubyVersionChecker do
  subject(:checker) { described_class.new }

  let(:api_response) do
    JSON.generate([
                    { cycle: "4.0", eol: false, latest: "4.0.2" },
                    { cycle: "3.4", eol: false, latest: "3.4.4" },
                    { cycle: "3.3", eol: false, latest: "3.3.9" },
                    { cycle: "3.2", eol: true,  latest: "3.2.8" }
                  ])
  end

  before { allow(Net::HTTP).to receive(:get).and_return(api_response) }

  describe "#latest_stable" do
    it "returns the highest non-EOL latest version" do
      expect(checker.latest_stable).to eq("4.0.2")
    end
  end

  describe "#maintained_minors" do
    it "returns non-EOL minors sorted ascending" do
      expect(checker.maintained_minors).to eq(%w[3.3 3.4 4.0])
    end
  end

  context "when the API is unreachable" do
    before { allow(Net::HTTP).to receive(:get).and_raise(StandardError) }

    it "returns nil for latest_stable" do
      expect(checker.latest_stable).to be_nil
    end

    it "returns an empty array for maintained_minors" do
      expect(checker.maintained_minors).to eq([])
    end
  end
end
