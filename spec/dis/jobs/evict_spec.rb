# frozen_string_literal: true

require "spec_helper"

describe Dis::Jobs::Evict do
  let(:job) { described_class.new }

  describe "#perform" do
    it "performs the job" do
      allow(Dis::Storage).to receive(:evict_caches)
      job.perform
      expect(Dis::Storage).to have_received(:evict_caches)
    end
  end
end
