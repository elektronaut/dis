# frozen_string_literal: true

require "spec_helper"

describe Dis::Storage do
  let(:type) { "test_files" }
  let(:root_path) { Rails.root.join("tmp/spec") }
  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:file) do
    File.open(File.expand_path("../support/fixtures/file.txt", __dir__))
  end
  let(:uploaded_file) { Rack::Test::UploadedFile.new(file, "text/plain") }
  let(:connection) do
    Fog::Storage.new(provider: "Local", local_root: root_path)
  end
  let(:layer) { Dis::Layer.new(connection, path: "layer1") }
  let(:second_layer) { Dis::Layer.new(connection, path: "layer2") }
  let(:delayed_layer) do
    Dis::Layer.new(connection, path: "delayed", delayed: true)
  end
  let(:readonly_layer) do
    Dis::Layer.new(connection, path: "readonly", readonly: true)
  end
  let(:all_layers) { [layer, second_layer, delayed_layer, readonly_layer] }

  before do
    described_class.layers.clear!
    allow(Dis::Jobs::ChangeType).to receive(:perform_later)
    allow(Dis::Jobs::Delete).to receive(:perform_later)
    allow(Dis::Jobs::Store).to receive(:perform_later)
  end

  after do
    FileUtils.rm_rf(root_path)
  end

  describe ".file_digest" do
    subject { described_class.file_digest(input) }

    let(:input) { file }

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

    it "takes a block" do
      described_class.file_digest(input) do |h|
        expect(h).to eq(hash)
      end
    end
  end

  describe ".layers" do
    it "is an instance of Dis::Layers" do
      expect(described_class.layers).to be_a(Dis::Layers)
    end
  end

  describe ".store" do
    context "with no immediately writeable layers" do
      before do
        described_class.layers << delayed_layer
        described_class.layers << readonly_layer
      end

      it "raises an error" do
        expect do
          described_class.store(type, file)
        end.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "with a file input" do
      before { all_layers.each { |layer| described_class.layers << layer } }

      it "returns the hash" do
        expect(described_class.store(type, file)).to eq(hash)
      end

      it "enqueues a job" do
        described_class.store(type, file)
        expect(Dis::Jobs::Store).to(
          have_received(:perform_later).with(type, hash)
        )
      end

      it "stores the file in the first immediate layer" do
        described_class.store(type, file)
        expect(layer.exists?(type, hash)).to be true
      end

      it "stores the file in all immediate layers" do
        described_class.store(type, file)
        expect(second_layer.exists?(type, hash)).to be true
      end

      it "does not store the file in delayed layers" do
        described_class.store(type, file)
        expect(delayed_layer.exists?(type, hash)).to be false
      end

      it "does not store the file in readonly layers" do
        described_class.store(type, file)
        expect(readonly_layer.exists?(type, hash)).to be false
      end
    end

    context "with a string input" do
      let(:file) { "foobar" }

      before { described_class.layers << layer }

      it "returns the hash" do
        expect(described_class.store(type, file)).to eq(hash)
      end
    end

    context "with an UploadedFile input" do
      before { described_class.layers << layer }

      it "returns the hash" do
        expect(described_class.store(type, uploaded_file)).to eq(hash)
      end
    end
  end

  describe ".delayed_store" do
    before { all_layers.each { |layer| described_class.layers << layer } }

    context "when the file doesn't exist" do
      it "raises an error" do
        expect do
          described_class.delayed_store(type, hash)
        end.to raise_error(Dis::Errors::NotFoundError)
      end
    end

    context "when the file exists" do
      before do
        layer.store(type, hash, file)
        described_class.delayed_store(type, hash)
      end

      it "copies the file to delayed layers" do
        expect(delayed_layer.exists?(type, hash)).to be true
      end

      it "does not copy the file to immediate layers" do
        expect(second_layer.exists?(type, hash)).to be false
      end

      it "does not copy the file to readonly layers" do
        expect(readonly_layer.exists?(type, hash)).to be false
      end
    end
  end

  describe ".exists?" do
    context "with no layers" do
      it "raises an error" do
        expect do
          described_class.exists?(type, hash)
        end.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "when the file exists in any layer" do
      before do
        all_layers.each { |layer| described_class.layers << layer }
        delayed_layer.store(type, hash, file)
      end

      it "returns true" do
        expect(described_class.exists?(type, hash)).to be true
      end
    end

    context "when the file doesn't exist" do
      before { all_layers.each { |layer| described_class.layers << layer } }

      it "returns false" do
        expect(described_class.exists?(type, hash)).to be false
      end
    end
  end

  describe ".get" do
    context "with no layers" do
      it "raises a NoLayersError" do
        expect do
          described_class.get(type, hash)
        end.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "when the file doesn't exist" do
      before { described_class.layers << layer }

      it "raises an NotFoundError" do
        expect do
          described_class.get(type, hash)
        end.to raise_error(Dis::Errors::NotFoundError)
      end
    end

    context "when the file exists in the first layer" do
      before do
        all_layers.each { |layer| described_class.layers << layer }
        layer.store(type, hash, file)
      end

      let!(:result) { described_class.get(type, hash) }

      it "finds the file" do
        expect(result).to be_a(Fog::Model)
      end

      it "does not replicate to the second layer" do
        expect(second_layer.exists?(type, hash)).to be false
      end
    end

    context "when the file exist, but not in the first layer" do
      before do
        all_layers.each { |layer| described_class.layers << layer }
        readonly_layer.send(:store!, type, hash, file)
      end

      let!(:result) { described_class.get(type, hash) }

      it "finds the file" do
        expect(result).to be_a(Fog::Model)
      end

      it "replicates to the first immediate layer" do
        expect(layer.exists?(type, hash)).to be true
      end

      it "replicates to all immediate layers" do
        expect(second_layer.exists?(type, hash)).to be true
      end

      it "does not replicate to delayed layers" do
        expect(delayed_layer.exists?(type, hash)).to be false
      end
    end
  end

  describe ".delete" do
    context "with no immediately writeable layers" do
      before do
        described_class.layers << delayed_layer
        described_class.layers << readonly_layer
      end

      it "raises an error" do
        expect do
          described_class.delete(type, hash)
        end.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "when the file exists" do
      before do
        all_layers.each do |layer|
          layer.send(:store!, type, hash, file)
          described_class.layers << layer
        end
      end

      it "returns true" do
        expect(described_class.delete(type, hash)).to be(true)
      end

      it "enqueues a job" do
        described_class.delete(type, hash)
        expect(Dis::Jobs::Delete).to(
          have_received(:perform_later).with(type, hash)
        )
      end

      it "deletes it from the first immediate layers" do
        described_class.delete(type, hash)
        expect(layer.exists?(type, hash)).to be false
      end

      it "deletes it from all immediate writeable layers" do
        described_class.delete(type, hash)
        expect(second_layer.exists?(type, hash)).to be false
      end

      it "does not delete it from readonly layers" do
        expect(readonly_layer.exists?(type, hash)).to be true
      end

      it "does not delete it from delayed layers" do
        expect(delayed_layer.exists?(type, hash)).to be true
      end
    end

    context "when the file doesn't exist" do
      before { described_class.layers << layer }

      it "returns false" do
        expect(described_class.delete(type, hash)).to be(false)
      end
    end
  end

  describe ".change_type" do
    let(:new_type) { "changed_test_files" }

    context "with no immediately writeable layers" do
      before do
        described_class.layers << delayed_layer
        described_class.layers << readonly_layer
      end

      it "raises an error" do
        expect do
          described_class.change_type(type, new_type, hash)
        end.to raise_error(Dis::Errors::NoLayersError)
      end
    end

    context "when the file exists" do
      before do
        all_layers.each do |layer|
          layer.send(:store!, type, hash, file)
          described_class.layers << layer
        end
        described_class.change_type(type, new_type, hash)
      end

      it "returns the hash" do
        expect(described_class.change_type(type, new_type, hash)).to eq(hash)
      end

      it "enqueues a job" do
        expect(Dis::Jobs::ChangeType).to(
          have_received(:perform_later).with(type, new_type, hash)
        )
      end

      it "stores it in the first immediate writeable layers" do
        expect(layer.exists?(new_type, hash)).to be true
      end

      it "deletes it in the first immediate writeable layers" do
        expect(layer.exists?(type, hash)).to be false
      end

      it "stores it in all immediate writeable layers" do
        expect(second_layer.exists?(new_type, hash)).to be true
      end

      it "deletes it in all immediate writeable layers" do
        expect(second_layer.exists?(type, hash)).to be false
      end

      it "does not store in readonly layers" do
        expect(readonly_layer.exists?(new_type, hash)).to be false
      end

      it "does not delete in readonly layers" do
        expect(readonly_layer.exists?(type, hash)).to be true
      end

      it "does not store in delayed layers" do
        expect(delayed_layer.exists?(new_type, hash)).to be false
      end

      it "does not delete in delayed layers" do
        expect(delayed_layer.exists?(type, hash)).to be true
      end
    end

    context "when the file doesn't exist" do
      before { described_class.layers << layer }

      it "raises an error" do
        expect do
          described_class.change_type(type, new_type, hash)
        end.to raise_error(Dis::Errors::NotFoundError)
      end
    end
  end

  describe ".delayed_delete" do
    before do
      all_layers.each do |layer|
        described_class.layers << layer
        layer.send(:store!, type, hash, file)
      end
      described_class.delayed_delete(type, hash)
    end

    it "deletes the file from delayed layers" do
      expect(delayed_layer.exists?(type, hash)).to be false
    end

    it "does not delete the file from immediate layers" do
      expect(layer.exists?(type, hash)).to be true
    end

    it "does not delete the file from readonly layers" do
      expect(readonly_layer.exists?(type, hash)).to be true
    end
  end
end
