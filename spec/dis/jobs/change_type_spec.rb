# frozen_string_literal: true

require "spec_helper"

describe Dis::Jobs::ChangeType do
  let(:type) { "test_files" }
  let(:new_type) { "changed_test_files" }
  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:job) { described_class.new }

  describe "#perform" do
    before do
      allow(Dis::Storage).to receive(:delayed_store)
      allow(Dis::Storage).to receive(:delayed_delete)
    end

    it "stores the new object" do
      job.perform(type, new_type, hash)
      expect(Dis::Storage).to have_received(:delayed_store).with(new_type, hash)
    end

    it "deletes the old object" do
      job.perform(type, new_type, hash)
      expect(Dis::Storage).to have_received(:delayed_delete).with(type, hash)
    end
  end
end
