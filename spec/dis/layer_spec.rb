# encoding: utf-8

require 'spec_helper'

describe Dis::Layer do
  let(:type)        { 'test_files' }
  let(:root_path)   { Rails.root.join('tmp', 'spec') }
  let(:target_path) { root_path.join(type, '88', '43d7f92416211de9ebb963ff4ce28125932878') }
  let(:hash)        { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:file)        { File.open(File.expand_path("../../support/fixtures/file.txt", __FILE__)) }
  let(:connection)  { Fog::Storage.new({provider: 'Local', local_root: root_path}) }
  let(:layer)       { Dis::Layer.new(connection) }

  after { FileUtils.rm_rf(root_path) if File.exist?(root_path) }

  describe "#delayed?" do
    subject { layer.delayed? }

    context "when the layer is delayed" do
      let(:layer) { Dis::Layer.new(connection, delayed: true) }
      it { should be true }
    end

    context "when the layer isn't delayed" do
      let(:layer) { Dis::Layer.new(connection, delayed: false) }
      it { should be false }
    end
  end

  describe "#immediate?" do
    subject { layer.immediate? }

    context "when the layer is delayed" do
      let(:layer) { Dis::Layer.new(connection, delayed: true) }
      it { should be false }
    end

    context "when the layer isn't delayed" do
      let(:layer) { Dis::Layer.new(connection, delayed: false) }
      it { should be true }
    end
  end

  describe "#public?" do
    subject { layer.public? }

    context "when the layer is public" do
      let(:layer) { Dis::Layer.new(connection, public: true) }
      it { should be true }
    end

    context "when the layer isn't public" do
      let(:layer) { Dis::Layer.new(connection, public: false) }
      it { should be false }
    end
  end

  describe "#readonly?" do
    subject { layer.readonly? }

    context "when the layer is readonly" do
      let(:layer) { Dis::Layer.new(connection, readonly: true) }
      it { should be true }
    end

    context "when the layer isn't readonly" do
      let(:layer) { Dis::Layer.new(connection, readonly: false) }
      it { should be false }
    end
  end

  describe "#writeable?" do
    subject { layer.writeable? }

    context "when the layer is readonly" do
      let(:layer) { Dis::Layer.new(connection, readonly: true) }
      it { should be false }
    end

    context "when the layer isn't readonly" do
      let(:layer) { Dis::Layer.new(connection, readonly: false) }
      it { should be true }
    end
  end

  describe "#get" do
    let(:result) { layer.get(type, hash) }

    context "when the file exists" do
      before { layer.store(type, hash, file) }

      it "should retrieve the file" do
        expect(result).to be_a(Fog::Model)
        expect(result.body).to eq("foobar")
      end
    end

    context "when the file doesn't exist" do
      it "should return nil" do
        expect(result).to be_nil
      end
    end

    context "when the file doesn't exist, but the path does" do
      before { FileUtils.mkdir_p(root_path.join(type, '88')) }
      it "should return nil" do
        expect(result).to be_nil
      end
    end
  end

  describe "#exists?" do
    subject { layer.exists?(type, hash) }

    context "when the file exists" do
      before { layer.store(type, hash, file) }
      it { should be true }
    end

    context "when the file doesn't exist" do
      it { should be false }
    end
  end

  describe "#store" do
    let(:result) { layer.store(type, hash, file) }

    context "with a file" do
      before { result }

      it "creates the directory" do
        expect(File.exist?(root_path)).to be true
      end

      it "stores the file" do
        expect(File.exist?(target_path)).to be true
        expect(File.read(target_path)).to eq("foobar")
      end
    end

    context "with a file and a path" do
      let(:layer)       { Dis::Layer.new(connection, path: 'mypath') }
      let(:target_path) { root_path.join('mypath', type, '88', '43d7f92416211de9ebb963ff4ce28125932878') }
      let!(:result) { layer.store(type, hash, file) }

      it "returns the file" do
        expect(result).to be_a(Fog::Model)
      end

      it "creates the directory" do
        expect(File.exist?(root_path)).to be true
      end

      it "stores the file" do
        expect(File.exist?(target_path)).to be true
        expect(File.read(target_path)).to eq("foobar")
      end
    end

    context "when the file already exists" do
      before { layer.store(type, hash, file) }

      it "returns the file" do
        expect(result).to be_a(Fog::Model)
      end
    end

    context "when layer is readonly" do
      let(:layer) { Dis::Layer.new(connection, readonly: true) }
      it "raises an error" do
        expect { result }.to raise_error(Dis::Errors::ReadOnlyError)
      end
    end
  end

  describe "#delete" do
    let(:result) { layer.delete(type, hash) }

    context "when the file exists" do
      before { layer.store(type, hash, file) }
      let!(:result) { layer.delete(type, hash) }

      it "returns true" do
        expect(result).to be true
      end

      it "deletes the file" do
        expect(File.exist?(target_path)).to be false
      end
    end

    context "when the file doesn't exist" do
      it "returns nil" do
        expect(result).to be false
      end
    end

    context "when the layer is readonly" do
      let(:layer) { Dis::Layer.new(connection, readonly: true) }

      it "raises an error" do
        expect { result }.to raise_error(Dis::Errors::ReadOnlyError)
      end
    end
  end
end
