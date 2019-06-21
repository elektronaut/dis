# frozen_string_literal: true

require "spec_helper"

describe Dis::Layers do
  let(:connection)     { nil }
  let(:layer)          { Dis::Layer.new(connection) }
  let(:delayed_layer)  { Dis::Layer.new(connection, delayed: true) }
  let(:readonly_layer) { Dis::Layer.new(connection, readonly: true) }
  let(:layers)         { described_class.new }

  describe "#clear!" do
    before { layers << layer }

    it "clears the layers" do
      expect { layers.clear! }.to change(layers, :count).by(-1)
    end
  end

  describe "#delayed" do
    before do
      layers << layer
      layers << delayed_layer
    end

    it "only returns the delayed layers" do
      expect(layers.delayed.to_a).to eq([delayed_layer])
    end

    it "returns an instance of itself" do
      expect(layers.delayed).to be_a(described_class)
    end
  end

  describe "#delayed?" do
    subject { layers.delayed? }

    context "with no layers" do
      it { is_expected.to be false }
    end

    context "with only immediate layers" do
      before { layers << layer }

      it { is_expected.to be false }
    end

    context "with delayed layers" do
      before { layers << delayed_layer }

      it { is_expected.to be true }
    end
  end

  describe "#immediate" do
    before do
      layers << layer
      layers << delayed_layer
    end

    it "only returns the immediate layers" do
      expect(layers.immediate.to_a).to eq([layer])
    end

    it "returns an instance of itself" do
      expect(layers.immediate).to be_a(described_class)
    end
  end

  describe "#immediate?" do
    subject { layers.immediate? }

    context "with no layers" do
      it { is_expected.to be false }
    end

    context "with only delayed layers" do
      before { layers << delayed_layer }

      it { is_expected.to be false }
    end

    context "with immediate layers" do
      before { layers << layer }

      it { is_expected.to be true }
    end
  end

  describe "#readonly" do
    before do
      layers << layer
      layers << readonly_layer
    end

    it "only return the readonly layers" do
      expect(layers.readonly.to_a).to eq([readonly_layer])
    end

    it "returns an instance of itself" do
      expect(layers.readonly).to be_a(described_class)
    end
  end

  describe "#readonly?" do
    subject { layers.readonly? }

    context "with no layers" do
      it { is_expected.to be false }
    end

    context "with no readonly layers" do
      before { layers << layer }

      it { is_expected.to be false }
    end

    context "with readonly layers" do
      before { layers << readonly_layer }

      it { is_expected.to be true }
    end
  end

  describe "#writeable" do
    before do
      layers << layer
      layers << readonly_layer
    end

    it "only returns the writeable layers" do
      expect(layers.writeable.to_a).to eq([layer])
    end

    it "returns an instance of itself" do
      expect(layers.writeable).to be_a(described_class)
    end
  end

  describe "#writeable?" do
    subject { layers.writeable? }

    context "with no layers" do
      it { is_expected.to be false }
    end

    context "with no writeable layers" do
      before { layers << readonly_layer }

      it { is_expected.to be false }
    end

    context "with writeable layers" do
      before { layers << layer }

      it { is_expected.to be true }
    end
  end
end
