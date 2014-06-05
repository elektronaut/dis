require 'spec_helper'

describe BlobDispenser::Layers do
  let(:connection)    { nil }
  let(:layer)         { BlobDispenser::Layer.new(connection) }
  let(:delayed_layer) { BlobDispenser::Layer.new(connection, delayed: true) }
  let(:layers)        { BlobDispenser::Layers.new }

  describe ".delayed" do
    before do
      layers << layer
      layers << delayed_layer
    end

    it "should only return the delayed layers" do
      expect(layers.delayed).to include(delayed_layer)
      expect(layers.delayed).not_to include(layer)
    end
  end

  describe ".delayed?" do
    subject { layers.delayed? }
    context "with no layers" do
      it { should be_false }
    end

    context "with only immediate layers" do
      before { layers << layer }
      it { should be_false }
    end

    context "with delayed layers" do
      before { layers << delayed_layer }
      it { should be_true }
    end
  end

  describe ".immediate" do
    before do
      layers << layer
      layers << delayed_layer
    end

    it "should only return the immediate layers" do
      expect(layers.immediate).to include(layer)
      expect(layers.immediate).not_to include(delayed_layer)
    end
  end

  describe ".immediate?" do
    subject { layers.immediate? }
    context "with no layers" do
      it { should be_false }
    end

    context "with only delayed layers" do
      before { layers << delayed_layer }
      it { should be_false }
    end

    context "with immediate layers" do
      before { layers << layer }
      it { should be_true }
    end
  end
end