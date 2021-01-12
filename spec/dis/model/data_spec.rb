# frozen_string_literal: true

require "spec_helper"

describe Dis::Model::Data do
  root_path = Rails.root.join("tmp/spec")

  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:file) do
    File.open(File.expand_path("../../support/fixtures/file.txt", __dir__))
  end
  let(:uploaded_file) { Rack::Test::UploadedFile.new(file, "text/plain") }
  let(:image) { Image.new }
  let(:data) { described_class.new(image) }

  before do
    Dis::Storage.layers.clear!
    Dis::Storage.layers << Dis::Layer.new(
      Fog::Storage.new(provider: "Local", local_root: root_path)
    )
  end

  after do
    FileUtils.rm_rf(root_path) if File.exist?(root_path)
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
      it { is_expected.to be nil }
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
end
