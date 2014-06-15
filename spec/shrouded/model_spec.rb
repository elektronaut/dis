# encoding: utf-8

require 'spec_helper'

describe Shrouded::Model do
  let(:hash)          { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:content_type)  { 'text/plain' }
  let(:filename)      { 'file.txt' }
  let(:root_path)     { Rails.root.join('tmp', 'spec') }
  let(:file)          { File.open(File.expand_path("../../support/fixtures/file.txt", __FILE__)) }
  let(:uploaded_file) { Rack::Test::UploadedFile.new(file, content_type) }
  let(:connection)    { Fog::Storage.new({provider: 'Local', local_root: root_path}) }
  let(:layer)         { Shrouded::Layer.new(connection) }

  before do
    Shrouded::Storage.layers << layer
  end

  after do
    FileUtils.rm_rf(root_path) if File.exists?(root_path)
    Shrouded::Storage.layers.clear!
  end

  describe "#data" do
    context "when loading from the store" do
      let(:existing_image) { Image.create(data: uploaded_file, accept: true) }
      let(:image) { Image.find(existing_image.id) }
      it "should return the content" do
        expect(image.data).to eq("foobar")
      end
    end

    context "when data is set" do
      let(:image) { Image.new(data: uploaded_file) }
      it "should return the content" do
        expect(image.data).to eq("foobar")
      end
    end

    context "when data isn't set" do
      let(:image) { Image.new }
      it "should return nil" do
        expect(image.data).to be nil
      end
    end
  end

  describe "#data=" do
    let(:image) { Image.new }
    before { image.data = uploaded_file }

    it "should set the content length" do
      expect(image.content_length).to eq(6)
    end

    it "should not store the file" do
      expect(layer.exists?("images", hash)).to be false
    end

    context "with an existing object" do
      let(:image) { Image.create(file: uploaded_file, accept: true) }

      it "should reset the content hash" do
        expect(image.content_hash).to be nil
      end
    end
  end

  describe "#data_changed?" do
    let(:image) { Image.new }
    subject { image.data_changed? }

    context "with no changes" do
      it { is_expected.to be false }
    end

    context "when attribute is being set" do
      let(:image) { Image.new(data: uploaded_file) }
      it { is_expected.to be true }
    end

    context "when the object has been persisted" do
      let(:existing_image) { Image.create(file: uploaded_file, accept: true) }
      let(:image) { Image.find(existing_image.id) }

      context "and the data is the same" do
        before { image.data = uploaded_file }
        it { is_expected.to be false }
      end

      context "and the data changes" do
        before { image.data = "new" }
        it { is_expected.to be true }
      end
    end
  end

  describe "#data?" do
    let(:image) { Image.new }
    subject(:result) { image.data? }

    context "when data hasn't been set" do
      it "should be false" do
        expect(result).to be false
      end
    end

    context "when data has been set" do
      before { image.data = uploaded_file }
      it "should be true" do
        expect(result).to be true
      end
    end

    context "when the object has been saved" do
      let(:existing_image) { Image.create(data: uploaded_file, accept: true) }
      let(:image) { Image.find(existing_image.id) }
      it "should be true" do
        expect(result).to be true
      end
    end

    context "when the object has been saved, but data has been set to nil" do
      let(:existing_image) { Image.create(data: uploaded_file, accept: true) }
      let(:image) { Image.find(existing_image.id) }
      before { image.data = nil }
      it "should be true" do
        expect(result).to be false
      end
    end
  end

  describe "#file=" do
    let(:image) { Image.new }

    context "with an uploaded file" do
      before { image.file = uploaded_file }

      it "should set the filename" do
        expect(image.filename).to eq(filename)
      end

      it "should set the content type" do
        expect(image.content_type).to eq(content_type)
      end

      it "should set the content length" do
        expect(image.content_length).to eq(6)
      end

      it "should not store the file" do
        expect(layer.exists?("images", hash)).to be false
      end
    end
  end

  describe "storage callback" do
    context "when object is invalid" do
      let!(:image) { Image.create(data: uploaded_file) }

      it "should not store the file" do
        expect(layer.exists?("images", hash)).to be false
      end
    end

    context "when object is valid" do
      let!(:image) { Image.create(data: uploaded_file, accept: true) }

      it "should update the content hash" do
        expect(image.content_hash).to eq(hash)
      end

      it "should store the file" do
        expect(layer.exists?("images", hash)).to be true
      end
    end

    context "when data changes to nil" do
      let!(:image) { Image.create(data: uploaded_file, accept: true) }
      before { image.update(data: nil, accept: true) }

      it "should remove the old file" do
        expect(layer.exists?("images", hash)).to be false
      end

      it "should be nil when reloaded" do
        expect(Image.find(image.id).data).to be nil
      end
    end

    context "when data changes to a new file" do
      let(:new_hash)          { 'aa1d7eef5b608ac42d09af74bb012bb29c9c57dd' }
      let(:new_file)          { File.open(File.expand_path("../../support/fixtures/other_file.txt", __FILE__)) }
      let(:new_uploaded_file) { Rack::Test::UploadedFile.new(new_file, content_type) }
      let!(:image)            { Image.create(data: uploaded_file, accept: true) }

      context "and the object is valid" do
        before { image.update(data: new_uploaded_file, accept: true) }

        it "should store the new file" do
          expect(layer.exists?("images", new_hash)).to be true
        end

        it "should remove the old file" do
          expect(layer.exists?("images", hash)).to be false
        end
      end

      context "and the object is not valid" do
        before { image.update(data: new_uploaded_file, accept: nil) }

        it "should not store the new file" do
          expect(image.valid?).to be false
          expect(layer.exists?("images", new_hash)).to be false
        end

        it "should not remove the old file" do
          expect(layer.exists?("images", hash)).to be true
        end
      end

      context "when another record exists" do
        before { Image.create(data: uploaded_file, accept: true) }
        before { image.update(data: new_uploaded_file, accept: true) }

        it "should not remove the old file" do
          expect(layer.exists?("images", hash)).to be true
        end
      end

    end
  end

  describe "delete callback" do
    context "when duplicates exist" do
      let!(:image) { Image.create(data: uploaded_file, accept: true) }
      let!(:other_image) { Image.create(data: uploaded_file, accept: true) }
      before { image.destroy }

      it "should not remove the file" do
        expect(layer.exists?("images", hash)).to be true
      end
    end

    context "when no duplicates exist" do
      let!(:image) { Image.create(data: uploaded_file, accept: true) }
      before { image.destroy }

      it "should remove the file" do
        expect(layer.exists?("images", hash)).to be false
      end
    end
  end
end