# frozen_string_literal: true

require "spec_helper"

describe Dis::Jobs::Delete do
  let(:type) { "test_files" }
  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:job)  { described_class.new }

  describe "#perform" do
    it "performs the job" do
      allow(Dis::Storage).to receive(:delayed_delete)
      job.perform(type, hash)
      expect(Dis::Storage).to have_received(:delayed_delete).with(type, hash)
    end
  end
end
