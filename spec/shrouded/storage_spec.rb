# encoding: utf-8

require 'spec_helper'

describe Shrouded::Storage do
  let(:root_path)      { Rails.root.join('tmp', 'spec') }
  let(:hash)           { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:file)           { File.open(File.expand_path("../../support/fixtures/file.txt", __FILE__)) }
  let(:uploaded_file)  { Rack::Test::UploadedFile.new(file, 'text/plain') }
  let(:connection)     { Fog::Storage.new({provider: 'Local', local_root: root_path}) }
  let(:layer)          { Shrouded::Layer.new(connection, path: 'layer1') }
  let(:second_layer)   { Shrouded::Layer.new(connection, path: 'layer2') }
  let(:delayed_layer)  { Shrouded::Layer.new(connection, path: 'delayed', delayed: true) }
  let(:readonly_layer) { Shrouded::Layer.new(connection, path: 'readonly', readonly: true) }
  let(:all_layers)     { [layer, second_layer, delayed_layer, readonly_layer] }

  after { FileUtils.rm_rf(root_path) if File.exists?(root_path) }
  after { Shrouded::Storage.layers.clear! }

  describe "#layers" do
    it "should be an instance of Shrouded::Layers" do
      expect(Shrouded::Storage.layers).to be_a(Shrouded::Layers)
    end
  end

  describe "#store" do
    context "with no immediately writeable layers" do
      before do
        Shrouded::Storage.layers << delayed_layer
        Shrouded::Storage.layers << readonly_layer
      end

      it "should raise an error" do
        expect { Shrouded::Storage.store(file) }.to raise_error(Shrouded::Errors::NoLayersError)
      end
    end

    context "with a file input" do
      before { all_layers.each { |layer| Shrouded::Storage.layers << layer } }

      it "should return the hash" do
        expect(Shrouded::Storage.store(file)).to eq(hash)
      end

      it "should store the file in immediate layers" do
        Shrouded::Storage.store(file)
        expect(layer.exists?(hash)).to be_true
        expect(second_layer.exists?(hash)).to be_true
      end

      it "should not store the file in delayed layers" do
        Shrouded::Storage.store(file)
        expect(delayed_layer.exists?(hash)).to be_false
      end

      it "should not store the file in readonly layers" do
        Shrouded::Storage.store(file)
        expect(readonly_layer.exists?(hash)).to be_false
      end
    end

    context "with a string input" do
      let(:file) { "foobar" }
      before { Shrouded::Storage.layers << layer }

      it "should return the hash" do
        expect(Shrouded::Storage.store(file)).to eq(hash)
      end
    end

    context "with an UploadedFile input" do
      before { Shrouded::Storage.layers << layer }

      it "should return the hash" do
        expect(Shrouded::Storage.store(uploaded_file)).to eq(hash)
      end
    end
  end

  describe "#exists?" do
    context "with no layers" do
      it "should raise an error" do
        expect { Shrouded::Storage.exists?(hash) }.to raise_error(Shrouded::Errors::NoLayersError)
      end
    end

    context "when the file exists in any layer" do
      before { all_layers.each { |layer| Shrouded::Storage.layers << layer } }
      before { delayed_layer.store(hash, file) }

      it "should return true" do
        expect(Shrouded::Storage.exists?(hash)).to be_true
      end
    end

    context "when the file doesn't exist" do
      before { all_layers.each { |layer| Shrouded::Storage.layers << layer } }

      it "should return false" do
        expect(Shrouded::Storage.exists?(hash)).to be_false
      end
    end
  end

  describe "#get" do
    context "with no layers" do
      it "should raise a NoLayersError" do
        expect { Shrouded::Storage.get(hash) }.to raise_error(Shrouded::Errors::NoLayersError)
      end
    end

    context "when the file doesn't exist" do
      before { Shrouded::Storage.layers << layer }

      it "should raise an NotFoundError" do
        expect { Shrouded::Storage.get(hash) }.to raise_error(Shrouded::Errors::NotFoundError)
      end
    end

    context "when the file exists in the first layer" do
      before { all_layers.each { |layer| Shrouded::Storage.layers << layer } }
      before { layer.store(hash, file) }
      let!(:result) { Shrouded::Storage.get(hash) }

      it "should find the file" do
        expect(result).to be_a(Fog::Model)
      end

      it "should not replicate to the second layer" do
        expect(second_layer.exists?(hash)).to be_false
      end
    end

    context "when the file exist, but not in the first layer" do
      before { all_layers.each { |layer| Shrouded::Storage.layers << layer } }
      before { readonly_layer.send(:store!, hash, file) }
      let!(:result) { Shrouded::Storage.get(hash) }

      it "should find the file" do
        expect(result).to be_a(Fog::Model)
      end

      it "should replicate to all immediate layers" do
        expect(layer.exists?(hash)).to be_true
        expect(second_layer.exists?(hash)).to be_true
      end

      it "should not replicate to delayed layers" do
        expect(delayed_layer.exists?(hash)).to be_false
      end
    end
  end

  describe "#delete" do
    context "with no immediately writeable layers" do
      before do
        Shrouded::Storage.layers << delayed_layer
        Shrouded::Storage.layers << readonly_layer
      end

      it "should raise an error" do
        expect { Shrouded::Storage.delete(hash) }.to raise_error(Shrouded::Errors::NoLayersError)
      end
    end

    context "when the file exists" do
      before do
        all_layers.each do |layer|
          layer.send(:store!, hash, file)
          Shrouded::Storage.layers << layer
        end
      end

      it "should return true" do
        expect(Shrouded::Storage.delete(hash)).to eq(true)
      end

      it "should delete it from all immediate writeable layers" do
        Shrouded::Storage.delete(hash)
        expect(layer.exists?(hash)).to be_false
        expect(second_layer.exists?(hash)).to be_false
      end

      it "should not delete it from readonly layers" do
        expect(readonly_layer.exists?(hash)).to be_true
      end

      it "should not delete it from delayed layers" do
        expect(delayed_layer.exists?(hash)).to be_true
      end
    end

    context "when the file doesn't exist" do
      before { Shrouded::Storage.layers << layer }

      it "should return false" do
        expect(Shrouded::Storage.delete(hash)).to eq(false)
      end
    end
  end
end