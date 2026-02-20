# frozen_string_literal: true

require "spec_helper"

describe Dis::Model do
  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:root_path) { Rails.root.join("tmp/spec") }
  let(:uploaded_file) do
    Rack::Test::UploadedFile.new(
      File.open(File.expand_path("../support/fixtures/file.txt", __dir__)),
      "text/plain"
    )
  end
  let(:layer) do
    Dis::Layer.new(Fog::Storage.new(provider: "Local", local_root: root_path))
  end

  before do
    Dis::Storage.layers << layer
  end

  after do
    FileUtils.rm_rf(root_path)
    Dis::Storage.layers.clear!
  end

  describe "#data" do
    context "when loading from the store" do
      let(:image) do
        Image.find(Image.create(data: uploaded_file, accept: true).id)
      end

      it "returns the content" do
        expect(image.data).to eq("foobar")
      end
    end

    context "when data is set" do
      let(:image) { Image.new(data: uploaded_file) }

      it "returns the content" do
        expect(image.data).to eq("foobar")
      end
    end

    context "when data isn't set" do
      let(:image) { Image.new }

      it "returns nil" do
        expect(image.data).to be_nil
      end
    end
  end

  describe "#data_file_path" do
    context "when the object has been saved" do
      let(:image) do
        Image.find(Image.create(data: uploaded_file, accept: true).id)
      end

      it "returns a path to the correct content" do
        expect(File.read(image.data_file_path)).to eq("foobar")
      end
    end
  end

  describe "#data=" do
    let(:image) { Image.new }

    before { image.data = uploaded_file }

    it "sets the content length" do
      expect(image.content_length).to eq(6)
    end

    it "sets the content hash" do
      expect(image.content_hash).to eq(hash)
    end

    it "does not store the file" do
      expect(layer.exists?("images", hash)).to be false
    end
  end

  describe "#data_changed?" do
    subject { image.data_changed? }

    let(:image) { Image.new }

    context "with no changes" do
      it { is_expected.to be false }
    end

    context "when attribute is being set" do
      let(:image) { Image.new(data: uploaded_file) }

      it { is_expected.to be true }
    end

    context "when the data changes" do
      let(:image) do
        Image.find(Image.create(file: uploaded_file, accept: true).id)
      end

      before { image.data = "new" }

      it { is_expected.to be true }
    end

    context "when the data changes to the same file" do
      let(:image) do
        Image.find(Image.create(file: uploaded_file, accept: true).id)
      end

      before { image.data = uploaded_file }

      it { is_expected.to be false }
    end
  end

  describe "#data?" do
    subject(:result) { image.data? }

    let(:image) { Image.new }

    context "when data hasn't been set" do
      it "is false" do
        expect(result).to be false
      end
    end

    context "when data has been set" do
      before { image.data = uploaded_file }

      it "is true" do
        expect(result).to be true
      end
    end

    context "when the object has been saved" do
      let(:image) do
        Image.find(Image.create(data: uploaded_file, accept: true).id)
      end

      it "is true" do
        expect(result).to be true
      end
    end

    context "when the object has been saved, but data has been set to nil" do
      let(:image) do
        Image.find(Image.create(data: uploaded_file, accept: true).id)
      end

      before { image.data = nil }

      it "is true" do
        expect(result).to be false
      end
    end
  end

  describe "#file=" do
    let(:image) { Image.new }

    context "with an uploaded file" do
      before { image.file = uploaded_file }

      it "sets the filename" do
        expect(image.filename).to eq("file.txt")
      end

      it "sets the content type" do
        expect(image.content_type).to eq("text/plain")
      end

      it "sets the content length" do
        expect(image.content_length).to eq(6)
      end

      it "does not store the file" do
        expect(layer.exists?("images", hash)).to be false
      end
    end
  end

  describe "storage callback" do
    let(:image) { Image.create(data: uploaded_file, accept: true) }
    let(:new_hash) { "aa1d7eef5b608ac42d09af74bb012bb29c9c57dd" }
    let(:new_file_path) { "../../support/fixtures/other_file.txt" }
    let(:new_file) { File.open(File.expand_path(new_file_path, __FILE__)) }
    let(:new_uploaded_file) do
      Rack::Test::UploadedFile.new(new_file, "text/plain")
    end

    context "when object is invalid" do
      let(:image) { Image.create(data: uploaded_file) }

      it "does not store the file" do
        expect(layer.exists?("images", hash)).to be false
      end
    end

    context "when object is valid" do
      before { image }

      it "updates the content hash" do
        expect(image.content_hash).to eq(hash)
      end

      it "stores the file" do
        expect(layer.exists?("images", hash)).to be true
      end
    end

    context "when data changes to nil" do
      before { image.update(data: nil, accept: true) }

      it "removes the old file" do
        expect(layer.exists?("images", hash)).to be false
      end

      it "is nil when reloaded" do
        expect(Image.find(image.id).data).to be_nil
      end
    end

    context "when data changes to a new file" do
      before { image.update(data: new_uploaded_file, accept: true) }

      it "stores the new file" do
        expect(layer.exists?("images", new_hash)).to be true
      end

      it "removes the old file" do
        expect(layer.exists?("images", hash)).to be false
      end
    end

    context "when the record is invalid" do
      before { image.update(data: new_uploaded_file, accept: nil) }

      it "is invalidated" do
        expect(image.valid?).to be false
      end

      it "does not store the new file" do
        expect(layer.exists?("images", new_hash)).to be false
      end

      it "does not remove the old file" do
        expect(layer.exists?("images", hash)).to be true
      end
    end

    context "when another record exists" do
      before do
        Image.create(data: uploaded_file, accept: true)
        image.update(data: new_uploaded_file, accept: true)
      end

      it "does not remove the old file" do
        expect(layer.exists?("images", hash)).to be true
      end
    end
  end

  describe "delete callback" do
    context "when duplicates exist" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }

      before do
        Image.create(data: uploaded_file, accept: true)
        image.destroy
      end

      it "does not remove the file" do
        expect(layer.exists?("images", hash)).to be true
      end
    end

    context "when no duplicates exist" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }

      before { image.destroy }

      it "removes the file" do
        expect(layer.exists?("images", hash)).to be false
      end
    end

    context "without data" do
      let(:image) { Image.create(data: nil, accept: true) }

      it "removes the file" do
        expect { image.destroy }.not_to raise_error
      end
    end
  end
end
