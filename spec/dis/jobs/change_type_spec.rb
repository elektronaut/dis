# encoding: utf-8

require 'spec_helper'

describe Dis::Jobs::Store do
  let(:type) { 'test_files' }
  let(:new_type) { 'changed_test_files' }
  let(:hash) { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:job) { Dis::Jobs::ChangeType.new }

  describe '#perform' do
    it 'should perform the job' do
      expect(Dis::Storage).to receive(:delayed_store).with(new_type, hash)
      expect(Dis::Storage).to receive(:delayed_delete).with(type, hash)
      job.perform(type, new_type, hash)
    end
  end
end
