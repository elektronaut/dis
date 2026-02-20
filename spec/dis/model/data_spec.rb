# frozen_string_literal: true

require "spec_helper"

describe Dis::Model::Data do
  subject(:data) { described_class.new(image) }

  let(:root_path) { Rails.root.join("tmp/spec") }
  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:file) do
    File.open(File.expand_path("../../support/fixtures/file.txt", __dir__))
  end
  let(:uploaded_file) { Rack::Test::UploadedFile.new(file, "text/plain") }
  let(:image) { Image.new }

  before do
    Dis::Storage.layers.clear!
    Dis::Storage.layers << Dis::Layer.new(
      Fog::Storage.new(provider: "Local", local_root: root_path)
    )
  end

  after do
    FileUtils.rm_rf(root_path)
  end

  describe "#==" do
    context "when comparing with nil" do
      it "returns false" do
        expect(data == nil).to be false # rubocop:disable Style/NilComparison
      end
    end

    context "when comparing with matching data" do
      subject(:data) { described_class.new(image, "test") }

      let(:other) { described_class.new(image, "test") }

      it { is_expected.to eq(other) }
    end

    context "when comparing with different data" do
      subject(:data) { described_class.new(image, "test") }

      let(:other) { described_class.new(image, "other") }

      it { is_expected.not_to eq(other) }
    end

    context "when both are stored with the same hash" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }
      let(:other_image) { Image.create(data: uploaded_file, accept: true) }
      let(:other) { described_class.new(other_image) }

      it "returns true" do
        expect(data == other).to be true
      end

      it "does not read from storage" do
        allow(Dis::Storage).to receive(:get).and_call_original
        _ = data == other
        expect(Dis::Storage).not_to have_received(:get)
      end
    end

    context "when both are stored with different hashes" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }
      let(:other_image) do
        Image.create(data: "different content", accept: true)
      end

      it "returns false" do
        other = described_class.new(other_image)
        expect(data == other).to be false
      end
    end

    context "when comparing stored data with raw data" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }
      let(:other) { described_class.new(image, "foobar") }

      it "falls back to reading" do
        expect(data == other).to be true
      end
    end
  end

  describe "#any?" do
    subject(:result) { data.any? }

    context "with no data" do
      it { is_expected.to be false }
    end

    context "with live data" do
      let(:data) { described_class.new(image, uploaded_file) }

      it { is_expected.to be true }
    end

    context "with stored data" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }

      it { is_expected.to be true }
    end
  end

  describe "#read" do
    subject(:result) { data.read }

    context "with no data" do
      it { is_expected.to be_nil }
    end

    context "with stored data" do
      let(:image) do
        Image.find(Image.create(data: uploaded_file, accept: true).id)
      end

      it { is_expected.to eq("foobar") }
    end

    context "with a string" do
      let(:data) { described_class.new(image, "test") }

      it { is_expected.to eq("test") }
    end

    context "with a File" do
      let(:data) { described_class.new(image, file) }

      it { is_expected.to eq("foobar") }
    end

    context "with an UploadedFile" do
      let(:data) { described_class.new(image, uploaded_file) }

      it { is_expected.to eq("foobar") }
    end
  end

  describe "#changed?" do
    subject(:result) { data.changed? }

    context "with no data set" do
      it { is_expected.to be false }
    end

    context "with data set" do
      let(:data) { described_class.new(image, "test") }

      it { is_expected.to be true }
    end
  end

  describe "#content_length" do
    subject(:result) { data.content_length }

    context "with no data" do
      it { is_expected.to eq(0) }
    end

    context "with stored data" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }

      it { is_expected.to eq(6) }
    end

    context "with a string" do
      let(:data) { described_class.new(image, "test") }

      it { is_expected.to eq(4) }
    end

    context "with a File" do
      let(:data) { described_class.new(image, file) }

      it { is_expected.to eq(6) }
    end

    context "with an UploadedFile" do
      let(:data) { described_class.new(image, uploaded_file) }

      it { is_expected.to eq(6) }
    end
  end

  describe "#expire" do
    before { allow(Dis::Storage).to receive(:delete) }

    context "when data is in use by other records" do
      before { Image.create(data: uploaded_file, accept: true) }

      it "does not delete the data" do
        data.expire(hash)
        expect(Dis::Storage).not_to have_received(:delete)
      end
    end

    context "when no other records use the hash" do
      it "deletes the data" do
        data.expire(hash)
        expect(Dis::Storage).to have_received(:delete).with("images", hash)
      end
    end
  end

  describe "#store!" do
    context "with no data" do
      it "raises an error" do
        expect { data.store! }.to raise_error(Dis::Errors::NoDataError)
      end
    end

    context "with data" do
      let(:data) { described_class.new(image, uploaded_file) }

      it "stores the data" do
        allow(Dis::Storage).to receive(:store)
        data.store!
        expect(Dis::Storage).to(
          have_received(:store).with("images", uploaded_file)
        )
      end

      it "returns the hash" do
        expect(data.store!).to eq(hash)
      end
    end
  end

  describe "#file_path" do
    subject(:result) { data.file_path }

    context "with stored data in local storage" do
      let(:image) do
        Image.find(Image.create(data: uploaded_file, accept: true).id)
      end

      it "returns the local storage path" do
        expect(result).to eq(
          Dis::Storage.file_path("images", hash)
        )
      end
    end

    context "with raw data" do
      let(:data) { described_class.new(image, "test") }

      it "returns a tempfile path" do
        expect(File.read(result)).to eq("test")
      end
    end
  end

  describe "#reset_read_cache!" do
    context "when nothing has been cached" do
      it "does not raise an error" do
        expect { data.reset_read_cache! }.not_to raise_error
      end
    end

    context "with cached read data" do
      let(:data) { described_class.new(image, "test") }

      before do
        data.read
        data.reset_read_cache!
      end

      it "allows data to be re-read" do
        expect(data.read).to eq("test")
      end
    end

    context "with a cached tempfile" do
      let(:data) { described_class.new(image, "test") }

      it "removes the tempfile from disk" do
        tempfile_path = data.tempfile.path
        data.reset_read_cache!
        expect(File.exist?(tempfile_path)).to be false
      end
    end

    context "with stored data" do
      let(:image) do
        Image.find(Image.create(data: uploaded_file, accept: true).id)
      end

      before do
        data.read
        data.reset_read_cache!
      end

      it "re-fetches from storage" do
        expect(data.read).to eq("foobar")
      end
    end
  end

  describe "#tempfile" do
    subject(:tempfile) { data.tempfile }

    let(:data) { described_class.new(image, uploaded_file) }

    it "contains the data" do
      expect(tempfile.read).to eq(uploaded_file.read)
    end

    it "caches the tempfile" do
      expect(tempfile.path).to eq(data.tempfile.path)
    end
  end
end
