# encoding: utf-8

require 'spec_helper'

describe Dis::Storage do
  let(:type)           { 'test_files' }
  let(:root_path)      { Rails.root.join('tmp', 'spec') }
  let(:hash)           { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:file)           { File.open(File.expand_path("../../support/fixtures/file.txt", __FILE__)) }
  let(:uploaded_file)  { Rack::Test::UploadedFile.new(file, 'text/plain') }
  let(:connection)     { Fog::Storage.new({provider: 'Local', local_root: root_path}) }
  let(:layer)          { Dis::Layer.new(connection, path: 'layer1') }
  let(:second_layer)   { Dis::Layer.new(connection, path: 'layer2') }
  let(:delayed_layer)  { Dis::Layer.new(connection, path: 'delayed', delayed: true) }
  let(:readonly_layer) { Dis::Layer.new(connection, path: 'readonly', readonly: true) }
  let(:all_layers)     { [layer, second_layer, delayed_layer, readonly_layer] }

  before do
    allow(Dis::Jobs::Delete).to receive(:perform_later)
    allow(Dis::Jobs::Store).to receive(:perform_later)
  end

  after do
    FileUtils.rm_rf(root_path) if File.exist?(root_path)
    Dis::Storage.layers.clear!
  end

  describe ".file_digest" do
    let(:input) { file }
    subject { Dis::Storage.file_digest(input) }

    context "when input is a Fog model" do
      let(:input) { layer.store(type, hash, file.read) }
      it { is_expected.to eq(hash) }
    end

    context "when input is a file" do
      it { is_expected.to eq(hash) }
    end

    context "when input is a string" do
      let(:input) { file.read }
      it { is_expected.to eq(hash) }
    end

    context "when input is an uploaded file" do
      let(:input) { uploaded_file }
      it { is_expected.to eq(hash) }
    end

    it "should take a block" do
      Dis::Storage.file_digest(input) do |h|
        expect(h).to eq(hash)
      end
    end
  end

  describe ".layers" do
    it "should be an instance of Dis::Layers" do
      expect(Dis::Storage.layers).to be_a(Dis::Layers)
    end
  end

  describe ".store" do
    context "with no immediately writeable layers" do
      before do
        Dis::Storage.layers << delayed_layer
        Dis::Storage.layers << readonly_layer
      end

      it "should raise an error" do
        expect { Dis::Storage.store(type, file) }.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "with a file input" do
      before { all_layers.each { |layer| Dis::Storage.layers << layer } }

      it "should return the hash" do
        expect(Dis::Storage.store(type, file)).to eq(hash)
      end

      it "should enqueue a job" do
        expect(Dis::Jobs::Store).to receive(:perform_later).with(type, hash)
        Dis::Storage.store(type, file)
      end

      it "should store the file in immediate layers" do
        Dis::Storage.store(type, file)
        expect(layer.exists?(type, hash)).to be true
        expect(second_layer.exists?(type, hash)).to be true
      end

      it "should not store the file in delayed layers" do
        Dis::Storage.store(type, file)
        expect(delayed_layer.exists?(type, hash)).to be false
      end

      it "should not store the file in readonly layers" do
        Dis::Storage.store(type, file)
        expect(readonly_layer.exists?(type, hash)).to be false
      end
    end

    context "with a string input" do
      let(:file) { "foobar" }
      before { Dis::Storage.layers << layer }

      it "should return the hash" do
        expect(Dis::Storage.store(type, file)).to eq(hash)
      end
    end

    context "with an UploadedFile input" do
      before { Dis::Storage.layers << layer }

      it "should return the hash" do
        expect(Dis::Storage.store(type, uploaded_file)).to eq(hash)
      end
    end
  end

  describe ".delayed_store" do
    before { all_layers.each { |layer| Dis::Storage.layers << layer } }

    context "when the file doesn't exist" do
      it "should raise an error" do
        expect { Dis::Storage.delayed_store(type, hash) }.to raise_error(Dis::Errors::NotFoundError)
      end
    end

    context "when the file exists" do
      before { layer.store(type, hash, file) }
      before { Dis::Storage.delayed_store(type, hash) }

      it "should copy the file to delayed layers" do
        expect(delayed_layer.exists?(type, hash)).to be true
      end

      it "should not copy the file to immediate layers" do
        expect(second_layer.exists?(type, hash)).to be false
      end

      it "should not copy the file to readonly layers" do
        expect(readonly_layer.exists?(type, hash)).to be false
      end
    end
  end

  describe ".exists?" do
    context "with no layers" do
      it "should raise an error" do
        expect { Dis::Storage.exists?(type, hash) }.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "when the file exists in any layer" do
      before { all_layers.each { |layer| Dis::Storage.layers << layer } }
      before { delayed_layer.store(type, hash, file) }

      it "should return true" do
        expect(Dis::Storage.exists?(type, hash)).to be true
      end
    end

    context "when the file doesn't exist" do
      before { all_layers.each { |layer| Dis::Storage.layers << layer } }

      it "should return false" do
        expect(Dis::Storage.exists?(type, hash)).to be false
      end
    end
  end

  describe ".get" do
    context "with no layers" do
      it "should raise a NoLayersError" do
        expect { Dis::Storage.get(type, hash) }.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "when the file doesn't exist" do
      before { Dis::Storage.layers << layer }

      it "should raise an NotFoundError" do
        expect { Dis::Storage.get(type, hash) }.to raise_error(Dis::Errors::NotFoundError)
      end
    end

    context "when the file exists in the first layer" do
      before { all_layers.each { |layer| Dis::Storage.layers << layer } }
      before { layer.store(type, hash, file) }
      let!(:result) { Dis::Storage.get(type, hash) }

      it "should find the file" do
        expect(result).to be_a(Fog::Model)
      end

      it "should not replicate to the second layer" do
        expect(second_layer.exists?(type, hash)).to be false
      end
    end

    context "when the file exist, but not in the first layer" do
      before { all_layers.each { |layer| Dis::Storage.layers << layer } }
      before { readonly_layer.send(:store!, type, hash, file) }
      let!(:result) { Dis::Storage.get(type, hash) }

      it "should find the file" do
        expect(result).to be_a(Fog::Model)
      end

      it "should replicate to all immediate layers" do
        expect(layer.exists?(type, hash)).to be true
        expect(second_layer.exists?(type, hash)).to be true
      end

      it "should not replicate to delayed layers" do
        expect(delayed_layer.exists?(type, hash)).to be false
      end
    end
  end

  describe ".delete" do
    context "with no immediately writeable layers" do
      before do
        Dis::Storage.layers << delayed_layer
        Dis::Storage.layers << readonly_layer
      end

      it "should raise an error" do
        expect { Dis::Storage.delete(type, hash) }.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "when the file exists" do
      before do
        all_layers.each do |layer|
          layer.send(:store!, type, hash, file)
          Dis::Storage.layers << layer
        end
      end

      it "should return true" do
        expect(Dis::Storage.delete(type, hash)).to eq(true)
      end

      it "should enqueue a job" do
        expect(Dis::Jobs::Delete).to receive(:perform_later).with(type, hash)
        Dis::Storage.delete(type, hash)
      end

      it "should delete it from all immediate writeable layers" do
        Dis::Storage.delete(type, hash)
        expect(layer.exists?(type, hash)).to be false
        expect(second_layer.exists?(type, hash)).to be false
      end

      it "should not delete it from readonly layers" do
        expect(readonly_layer.exists?(type, hash)).to be true
      end

      it "should not delete it from delayed layers" do
        expect(delayed_layer.exists?(type, hash)).to be true
      end
    end

    context "when the file doesn't exist" do
      before { Dis::Storage.layers << layer }

      it "should return false" do
        expect(Dis::Storage.delete(type, hash)).to eq(false)
      end
    end
  end

  describe ".delayed_delete" do
    before do
      all_layers.each do |layer|
        Dis::Storage.layers << layer
        layer.send(:store!, type, hash, file)
      end
      Dis::Storage.delayed_delete(type, hash)
    end
    before {  }

    it "should delete the file from delayed layers" do
      expect(delayed_layer.exists?(type, hash)).to be false
    end

    it "should not delete the file from immediate layers" do
      expect(layer.exists?(type, hash)).to be true
    end

    it "should not delete the file from readonly layers" do
      expect(readonly_layer.exists?(type, hash)).to be true
    end
  end
end
