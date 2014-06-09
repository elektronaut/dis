# encoding: utf-8

require 'spec_helper'

describe Shrouded::Jobs::Delete do
  let(:hash) { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:job) { Shrouded::Jobs::Delete.new }

  describe ".perform" do
    it "should perform the job" do
      expect(Shrouded::Storage).to receive(:delayed_delete).with(hash)
      job.perform(hash)
    end
  end
end
