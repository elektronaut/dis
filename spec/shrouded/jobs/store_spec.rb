# encoding: utf-8

require 'spec_helper'

describe Shrouded::Jobs::Store do
  let(:hash) { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:job) { Shrouded::Jobs::Store.new }

  before { Shrouded::Storage.stub(:delayed_store) }

  describe ".perform" do
    it "should perform the job" do
      Shrouded::Storage.should_receive(:delayed_store).with(hash)
      job.perform(hash)
    end
  end
end
