# frozen_string_literal: true

require "spec_helper"

describe Dis::Validations::DataPresence do
  subject { image.errors[:data] }

  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:root_path) { Rails.root.join("tmp/spec") }
  let(:uploaded_file) do
    Rack::Test::UploadedFile.new(
      File.open(File.expand_path("../../support/fixtures/file.txt", __dir__)),
      "text/plain"
    )
  end
  let(:image) { ImageWithValidations.new }

  before do
    Dis::Storage.layers.clear!
    Dis::Storage.layers << Dis::Layer.new(
      Fog::Storage.new(provider: "Local", local_root: root_path)
    )
    image.valid?
  end

  after do
    FileUtils.rm_rf(root_path)
  end

  context "with no data" do
    it { is_expected.to include("can't be blank") }
  end

  context "when data is a blank string" do
    let(:image) { ImageWithValidations.new(data: "") }

    it { is_expected.to include("can't be blank") }
  end

  context "when data is set" do
    let(:image) { ImageWithValidations.new(data: uploaded_file) }

    it { is_expected.to eq([]) }
  end

  context "when creating with content_hash" do
    let(:image) do
      ImageWithValidations.new(content_hash: hash, filename: "file.txt")
    end

    it { is_expected.to include("can't be blank") }
  end

  context "when data exists in storage" do
    let(:existing_image) do
      ImageWithValidations.create(data: uploaded_file, accept: true)
    end

    context "when finding an existing model" do
      let(:image) { ImageWithValidations.find(existing_image.id) }

      it { is_expected.to eq([]) }
    end

    context "when creating with content_hash" do
      let(:image) do
        ImageWithValidations.create(content_hash: existing_image.content_hash,
                                    filename: "file.txt")
      end

      it { is_expected.to eq([]) }

      it "foo" do
        expect(image.data).to eq("foobar")
      end
    end
  end
end
