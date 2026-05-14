# frozen_string_literal: true

RSpec.describe Rake::GemMaintenance::CIEnvironment do
  describe ".ci?" do
    subject(:ci?) { described_class.ci? }

    context "when CI env var is set to 'true'" do
      around { |ex| with_env("CI" => "true") { ex.run } }

      it { is_expected.to be true }
    end

    context "when CI env var is set to '1'" do
      around { |ex| with_env("CI" => "1") { ex.run } }

      it { is_expected.to be true }
    end

    context "when CI env var is set to empty string" do
      around { |ex| with_env("CI" => "") { ex.run } }

      it { is_expected.to be false }
    end

    context "when CI env var is not set" do
      around { |ex| with_env("CI" => nil) { ex.run } }

      it { is_expected.to be false }
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
