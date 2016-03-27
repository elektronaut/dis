# encoding: utf-8

require 'spec_helper'

describe Dis::Layers do
  let(:connection)     { nil }
  let(:layer)          { Dis::Layer.new(connection) }
  let(:delayed_layer)  { Dis::Layer.new(connection, delayed: true) }
  let(:readonly_layer) { Dis::Layer.new(connection, readonly: true) }
  let(:layers)         { Dis::Layers.new }

  describe '#clear!' do
    before { layers << layer }

    it 'clears the layers' do
      expect(layers.count).to eq(1)
      layers.clear!
      expect(layers.count).to eq(0)
    end
  end

  describe '#delayed' do
    before do
      layers << layer
      layers << delayed_layer
    end

    it 'should only return the delayed layers' do
      expect(layers.delayed).to include(delayed_layer)
      expect(layers.delayed).not_to include(layer)
    end

    it 'should return an instance of itself' do
      expect(layers.delayed).to be_a(Dis::Layers)
    end
  end

  describe '#delayed?' do
    subject { layers.delayed? }
    context 'with no layers' do
      it { should be false }
    end

    context 'with only immediate layers' do
      before { layers << layer }
      it { should be false }
    end

    context 'with delayed layers' do
      before { layers << delayed_layer }
      it { should be true }
    end
  end

  describe '#immediate' do
    before do
      layers << layer
      layers << delayed_layer
    end

    it 'should only return the immediate layers' do
      expect(layers.immediate).to include(layer)
      expect(layers.immediate).not_to include(delayed_layer)
    end

    it 'should return an instance of itself' do
      expect(layers.immediate).to be_a(Dis::Layers)
    end
  end

  describe '#immediate?' do
    subject { layers.immediate? }
    context 'with no layers' do
      it { should be false }
    end

    context 'with only delayed layers' do
      before { layers << delayed_layer }
      it { should be false }
    end

    context 'with immediate layers' do
      before { layers << layer }
      it { should be true }
    end
  end

  describe '#readonly' do
    before do
      layers << layer
      layers << readonly_layer
    end

    it 'should only return the readonly layers' do
      expect(layers.readonly).not_to include(layer)
      expect(layers.readonly).to include(readonly_layer)
    end

    it 'should return an instance of itself' do
      expect(layers.readonly).to be_a(Dis::Layers)
    end
  end

  describe '#readonly?' do
    subject { layers.readonly? }
    context 'with no layers' do
      it { should be false }
    end

    context 'with no readonly layers' do
      before { layers << layer }
      it { should be false }
    end

    context 'with readonly layers' do
      before { layers << readonly_layer }
      it { should be true }
    end
  end

  describe '#writeable' do
    before do
      layers << layer
      layers << readonly_layer
    end

    it 'should only return the writeable layers' do
      expect(layers.writeable).to include(layer)
      expect(layers.writeable).not_to include(readonly_layer)
    end

    it 'should return an instance of itself' do
      expect(layers.writeable).to be_a(Dis::Layers)
    end
  end

  describe '#writeable?' do
    subject { layers.writeable? }
    context 'with no layers' do
      it { should be false }
    end

    context 'with no writeable layers' do
      before { layers << readonly_layer }
      it { should be false }
    end

    context 'with writeable layers' do
      before { layers << layer }
      it { should be true }
    end
  end
end
