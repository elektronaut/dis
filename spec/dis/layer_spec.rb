# frozen_string_literal: true

require "spec_helper"

describe Dis::Layer do
  let(:type) { "test_files" }
  let(:root_path) { Rails.root.join("tmp", "spec") }
  let(:target_path) do
    root_path.join(type, "88", "43d7f92416211de9ebb963ff4ce28125932878")
  end
  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:file_path) { "../../support/fixtures/file.txt" }
  let(:file) { File.open(File.expand_path(file_path, __FILE__)) }
  let(:connection) do
    Fog::Storage.new(provider: "Local", local_root: root_path)
  end
  let(:layer) { described_class.new(connection) }

  after { FileUtils.rm_rf(root_path) if File.exist?(root_path) }

  describe "#delayed?" do
    subject { layer.delayed? }

    context "when the layer is delayed" do
      let(:layer) { described_class.new(connection, delayed: true) }

      it { is_expected.to be true }
    end

    context "when the layer isn't delayed" do
      let(:layer) { described_class.new(connection, delayed: false) }

      it { is_expected.to be false }
    end
  end

  describe "#immediate?" do
    subject { layer.immediate? }

    context "when the layer is delayed" do
      let(:layer) { described_class.new(connection, delayed: true) }

      it { is_expected.to be false }
    end

    context "when the layer isn't delayed" do
      let(:layer) { described_class.new(connection, delayed: false) }

      it { is_expected.to be true }
    end
  end

  describe "#public?" do
    subject { layer.public? }

    context "when the layer is public" do
      let(:layer) { described_class.new(connection, public: true) }

      it { is_expected.to be true }
    end

    context "when the layer isn't public" do
      let(:layer) { described_class.new(connection, public: false) }

      it { is_expected.to be false }
    end
  end

  describe "#readonly?" do
    subject { layer.readonly? }

    context "when the layer is readonly" do
      let(:layer) { described_class.new(connection, readonly: true) }

      it { is_expected.to be true }
    end

    context "when the layer isn't readonly" do
      let(:layer) { described_class.new(connection, readonly: false) }

      it { is_expected.to be false }
    end
  end

  describe "#writeable?" do
    subject { layer.writeable? }

    context "when the layer is readonly" do
      let(:layer) { described_class.new(connection, readonly: true) }

      it { is_expected.to be false }
    end

    context "when the layer isn't readonly" do
      let(:layer) { described_class.new(connection, readonly: false) }

      it { is_expected.to be true }
    end
  end

  describe "#get" do
    let(:result) { layer.get(type, hash) }

    context "when the file exists" do
      before { layer.store(type, hash, file) }

      it "returns a Fog::Model" do
        expect(result).to be_a(Fog::Model)
      end

      it "retrieves the file" do
        expect(result.body).to eq("foobar")
      end
    end

    context "when the file doesn't exist" do
      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when the file doesn't exist, but the path does" do
      before { FileUtils.mkdir_p(root_path.join(type, "88")) }

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe "#existing" do
    subject { layer.existing(type, keys) }

    let(:keys) { [hash, "a655c388fceaf194657339c3242562de66c2d102"] }

    before { layer.store(type, hash, file) }

    it { is_expected.to eq([hash]) }
  end

  describe "#exists?" do
    subject { layer.exists?(type, hash) }

    context "when the file exists" do
      before { layer.store(type, hash, file) }

      it { is_expected.to be true }
    end

    context "when the file doesn't exist" do
      it { is_expected.to be false }
    end
  end

  describe "#store" do
    let(:result) { layer.store(type, hash, file) }

    context "with a file" do
      before { result }

      it "creates the directory" do
        expect(File.exist?(root_path)).to be true
      end

      it "stores a file" do
        expect(File.exist?(target_path)).to be true
      end

      it "saves the content to the file" do
        expect(File.read(target_path)).to eq("foobar")
      end
    end

    context "with a file and a path" do
      let(:layer) { described_class.new(connection, path: "mypath") }
      let(:target_path) do
        root_path.join("mypath",
                       type,
                       "88",
                       "43d7f92416211de9ebb963ff4ce28125932878")
      end
      let!(:result) { layer.store(type, hash, file) }

      it "returns the file" do
        expect(result).to be_a(Fog::Model)
      end

      it "creates the directory" do
        expect(File.exist?(root_path)).to be true
      end

      it "stores a file" do
        expect(File.exist?(target_path)).to be true
      end

      it "saves the content to the file" do
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
      let(:layer) { described_class.new(connection, readonly: true) }

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
      let(:layer) { described_class.new(connection, readonly: true) }

      it "raises an error" do
        expect { result }.to raise_error(Dis::Errors::ReadOnlyError)
      end
    end
  end

  describe "#name" do
    subject { layer.name }

    context "without a path set" do
      it { is_expected.to eq("Fog::Local::Storage::Real/") }
    end

    context "with a path set" do
      let(:layer) { described_class.new(connection, path: "foo") }

      it { is_expected.to eq("Fog::Local::Storage::Real/foo") }
    end
  end
end
