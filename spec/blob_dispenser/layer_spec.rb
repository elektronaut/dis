require 'spec_helper'

describe BlobDispenser::Layer do
  let(:connection) { nil }

  describe ".delayed?" do
    subject { layer.delayed? }

    context "when layer is delayed" do
      let(:layer) { BlobDispenser::Layer.new(connection, delayed: true) }
      it { should be_true }
    end

    context "when layer isn't delayed" do
      let(:layer) { BlobDispenser::Layer.new(connection, delayed: false) }
      it { should be_false }
    end
  end

  describe ".immediate?" do
    subject { layer.immediate? }

    context "when layer is delayed" do
      let(:layer) { BlobDispenser::Layer.new(connection, delayed: true) }
      it { should be_false }
    end

    context "when layer isn't delayed" do
      let(:layer) { BlobDispenser::Layer.new(connection, delayed: false) }
      it { should be_true }
    end
  end

  describe ".readonly?" do
    subject { layer.readonly? }

    context "when layer is readonly" do
      let(:layer) { BlobDispenser::Layer.new(connection, readonly: true) }
      it { should be_true }
    end

    context "when layer isn't readonly" do
      let(:layer) { BlobDispenser::Layer.new(connection, readonly: false) }
      it { should be_false }
    end
  end

  describe ".writeable?" do
    subject { layer.writeable? }

    context "when layer is readonly" do
      let(:layer) { BlobDispenser::Layer.new(connection, readonly: true) }
      it { should be_false }
    end

    context "when layer isn't readonly" do
      let(:layer) { BlobDispenser::Layer.new(connection, readonly: false) }
      it { should be_true }
    end
  end
end