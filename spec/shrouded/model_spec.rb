require 'spec_helper'

describe Shrouded::Model do
  class WithCustomAttributes < ActiveRecord::Base
    shrouded_model attributes: { filename: :uploaded_filename, content_type: :type },
                   type: 'custom'
  end

  let(:hash)          { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:content_type)  { 'text/plain' }
  let(:filename)      { 'file.txt' }
  let(:root_path)     { Rails.root.join('tmp', 'spec') }
  let(:file)          { File.open(File.expand_path("../../support/fixtures/file.txt", __FILE__)) }
  let(:uploaded_file) { Rack::Test::UploadedFile.new(file, content_type) }
  let(:connection)    { Fog::Storage.new({provider: 'Local', local_root: root_path}) }
  let(:layer)         { Shrouded::Layer.new(connection) }

  subject { Image }

  before do
    Shrouded::Storage.layers << layer
  end

  after do
    FileUtils.rm_rf(root_path) if File.exists?(root_path)
    Shrouded::Storage.layers.clear!
  end

  describe ".shrouded_attributes" do
    subject(:attributes) { model.shrouded_attributes }

    context "with no attributes specified" do
      let(:model) { Image }
      it "should return the default attributes" do
        expect(attributes).to eq({
          content_hash: :content_hash,
          content_length: :content_length,
          content_type: :content_type,
          filename: :filename
        })
      end
    end

    context "with custom attributes" do
      let(:model) { WithCustomAttributes }
      it "should return the attributes" do
        expect(attributes).to eq({
          content_hash: :content_hash,
          content_length: :content_length,
          content_type: :type,
          filename: :uploaded_filename
        })
      end
    end
  end

  describe ".shrouded_type" do
    subject(:type) { model.shrouded_type }

    context "with no attributes specified" do
      let(:model) { Image }
      it "should return the table name" do
        expect(type).to eq("images")
      end
    end

    context "with custom attributes" do
      let(:model) { WithCustomAttributes }
      it "should return the type" do
        expect(type).to eq("custom")
      end
    end
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

    context "when data changes" do
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