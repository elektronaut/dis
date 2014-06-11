require 'spec_helper'

describe Shrouded::Model do
  class Image < ActiveRecord::Base
    shrouded_model
    attr_accessor :accept
    validates :accept, presence: true
  end

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

  describe "#shrouded_attributes" do
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

  describe "#shrouded_type" do
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

  describe ".data=" do
    let(:image) { Image.new }

    context "with an uploaded file" do
      before { image.data = uploaded_file }

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

  describe "Save callbacks" do
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
  end

  describe "Destroy callback" do
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