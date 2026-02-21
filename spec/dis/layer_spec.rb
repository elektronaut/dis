# frozen_string_literal: true

require "spec_helper"

describe Dis::Layer do
  let(:root_path) { Rails.root.join("tmp/spec") }
  let(:target_path) do
    root_path.join("test_files", "88", "43d7f92416211de9ebb963ff4ce28125932878")
  end
  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:file) do
    File.open(File.expand_path("../support/fixtures/file.txt", __dir__))
  end
  let(:connection) do
    Fog::Storage.new(provider: "Local", local_root: root_path)
  end
  let(:layer) { described_class.new(connection) }

  after { FileUtils.rm_rf(root_path) }

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

  describe "#cache?" do
    subject { layer.cache? }

    context "when the layer is a cache" do
      let(:layer) do
        described_class.new(connection, cache: 1024)
      end

      it { is_expected.to be true }
    end

    context "when the layer isn't a cache" do
      it { is_expected.to be false }
    end
  end

  describe "#max_size" do
    context "when the layer is a cache" do
      let(:layer) do
        described_class.new(connection, cache: 1024)
      end

      it "returns the cache size limit" do
        expect(layer.max_size).to eq(1024)
      end
    end

    context "when the layer isn't a cache" do
      it "returns nil" do
        expect(layer.max_size).to be_nil
      end
    end
  end

  describe "cache option validation" do
    it "raises ArgumentError when combined with delayed" do
      expect do
        described_class.new(connection, cache: 1024, delayed: true)
      end.to raise_error(ArgumentError, /cannot be delayed/)
    end

    it "raises ArgumentError when combined with readonly" do
      expect do
        described_class.new(connection, cache: 1024, readonly: true)
      end.to raise_error(ArgumentError, /cannot be readonly/)
    end
  end

  describe "#size" do
    context "with a local provider" do
      let(:layer) do
        described_class.new(connection, cache: 1024)
      end

      it "returns 0 when no files exist" do
        expect(layer.size).to eq(0)
      end

      it "returns the total size of stored files" do
        layer.store("test_files", hash, file)
        expect(layer.size).to be_positive
      end
    end

    context "with a non-local provider" do
      let(:connection) { double("connection") } # rubocop:disable RSpec/VerifiedDoubles
      let(:layer) do
        described_class.new(connection, cache: 1024)
      end

      it "returns 0" do
        expect(layer.size).to eq(0)
      end
    end
  end

  describe "#cached_files" do
    let(:layer) do
      described_class.new(connection, cache: 1024)
    end

    context "when files exist" do
      before { layer.store("test_files", hash, file) }

      it "returns one entry" do
        expect(layer.cached_files.length).to eq(1)
      end

      it "returns the correct type" do
        expect(layer.cached_files.first[:type]).to eq("test_files")
      end

      it "returns the correct key" do
        expect(layer.cached_files.first[:key]).to eq(hash)
      end

      it "returns entries sorted by mtime ascending" do
        second_hash = "a655c388fceaf194657339c3242562de66c2d102"
        layer.store("test_files", second_hash, file)
        entries = layer.cached_files
        expect(entries.first[:mtime]).to be <= entries.last[:mtime]
      end
    end

    context "when no files exist" do
      it "returns an empty array" do
        expect(layer.cached_files).to eq([])
      end
    end

    context "with a non-local provider" do
      let(:connection) { double("connection") } # rubocop:disable RSpec/VerifiedDoubles
      let(:layer) do
        described_class.new(connection, cache: 1024)
      end

      it "returns an empty array" do
        expect(layer.cached_files).to eq([])
      end
    end
  end

  describe "#get" do
    let(:result) { layer.get("test_files", hash) }

    context "when the file exists" do
      before { layer.store("test_files", hash, file) }

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
      before { FileUtils.mkdir_p(root_path.join("test_files", "88")) }

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe "#get on a cache layer" do
    let(:layer) do
      described_class.new(connection, cache: 1024)
    end
    let(:old_mtime) do
      layer.store("test_files", hash, file)
      File.mtime(target_path)
    end

    before do
      old_mtime
      sleep 0.05
      layer.get("test_files", hash)
    end

    it "touches the file mtime on cache hit" do
      expect(File.mtime(target_path)).to be > old_mtime
    end
  end

  describe "#existing" do
    subject { layer.existing("test_files", keys) }

    let(:keys) { [hash, "a655c388fceaf194657339c3242562de66c2d102"] }

    before { layer.store("test_files", hash, file) }

    it { is_expected.to eq([hash]) }
  end

  describe "#exists?" do
    subject { layer.exists?("test_files", hash) }

    context "when the file exists" do
      before { layer.store("test_files", hash, file) }

      it { is_expected.to be true }
    end

    context "when the file doesn't exist" do
      it { is_expected.to be false }
    end
  end

  describe "#store" do
    let(:result) { layer.store("test_files", hash, file) }

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
                       "test_files",
                       "88",
                       "43d7f92416211de9ebb963ff4ce28125932878")
      end
      let!(:result) { layer.store("test_files", hash, file) }

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
      before { layer.store("test_files", hash, file) }

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

  describe "#file_path" do
    subject(:result) { layer.file_path("test_files", hash) }

    context "with a local provider and existing file" do
      before { layer.store("test_files", hash, file) }

      it "returns the absolute path" do
        expect(result).to eq(target_path.to_s)
      end
    end

    context "with a local provider and a path option" do
      let(:layer) { described_class.new(connection, path: "mypath") }
      let(:target_path) do
        root_path.join("mypath",
                       "test_files",
                       "88",
                       "43d7f92416211de9ebb963ff4ce28125932878")
      end

      before { layer.store("test_files", hash, file) }

      it "returns the absolute path" do
        expect(result).to eq(target_path.to_s)
      end
    end

    context "with a local provider and non-existent file" do
      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with a non-local provider" do
      let(:connection) { double("connection") } # rubocop:disable RSpec/VerifiedDoubles

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end

  describe "#delete" do
    let(:result) { layer.delete("test_files", hash) }

    context "when the file exists" do
      before { layer.store("test_files", hash, file) }

      let!(:result) { layer.delete("test_files", hash) }

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
