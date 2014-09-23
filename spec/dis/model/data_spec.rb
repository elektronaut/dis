# encoding: utf-8

require 'spec_helper'

describe Dis::Model::Data do
  root_path = Rails.root.join('tmp', 'spec')

  let(:hash)          { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:file)          { File.open(File.expand_path("../../../support/fixtures/file.txt", __FILE__)) }
  let(:uploaded_file) { Rack::Test::UploadedFile.new(file, 'text/plain') }
  let(:image)         { Image.new }
  let(:data)          { Dis::Model::Data.new(image) }

  before(:all) do
    Dis::Storage.layers << Dis::Layer.new(Fog::Storage.new({provider: 'Local', local_root: root_path}))
  end

  after do
    FileUtils.rm_rf(root_path) if File.exists?(root_path)
  end

  after(:all) do
    Dis::Storage.layers.clear!
  end

  describe "#any?" do
    subject(:result) { data.any? }

    context "with no data" do
      it { should be false }
    end

    context "with live data" do
      let(:data) { Dis::Model::Data.new(image, uploaded_file) }
      it { should be true }
    end

    context "with stored data" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }
    end
  end

  describe "#read" do
    subject(:result) { data.read }

    context "with no data" do
      it { should be nil }
    end

    context "with stored data" do
      let(:existing_image) { Image.create(data: uploaded_file, accept: true) }
      let(:image) { Image.find(existing_image.id) }
      it { is_expected.to eq("foobar") }
    end

    context "with a string" do
      let(:data) { Dis::Model::Data.new(image, "test") }
      it { is_expected.to eq("test") }
    end

    context "with a File" do
      let(:data) { Dis::Model::Data.new(image, file) }
      it { should eq("foobar") }
    end

    context "with an UploadedFile" do
      let(:data) { Dis::Model::Data.new(image, uploaded_file) }
      it { should eq("foobar") }
    end
  end

  describe "#changed?" do
    subject(:result) { data.changed? }

    context "with no data set" do
      it { should be false }
    end

    context "with data set" do
      let(:data) { Dis::Model::Data.new(image, "test") }
      it { should be true }
    end
  end

  describe "#content_length" do
    subject(:result) { data.content_length }

    context "with no data" do
      it { should eq(0) }
    end

    context "with stored data" do
      let(:image) { Image.create(data: uploaded_file, accept: true) }
      it { should eq(6) }
    end

    context "with a string" do
      let(:data) { Dis::Model::Data.new(image, "test") }
      it { should eq(4) }
    end

    context "with a File" do
      let(:data) { Dis::Model::Data.new(image, file) }
      it { should eq(6) }
    end

    context "with an UploadedFile" do
      let(:data) { Dis::Model::Data.new(image, uploaded_file) }
      it { should eq(6) }
    end
  end

  describe "#expire" do
    context "when data is in use by other records" do
      before { Image.create(data: uploaded_file, accept: true) }
      it "should not delete the data" do
        expect(Dis::Storage).not_to receive(:delete)
        data.expire(hash)
      end
    end

    context "when no other records use the hash" do
      it "should delete the data" do
        expect(Dis::Storage).to receive(:delete).with("images", hash)
        data.expire(hash)
      end
    end
  end

  describe "#store!" do
    context "with no data" do
      it "should raise an error" do
        expect { data.store! }.to raise_error(Dis::Errors::NoDataError)
      end
    end

    context "with data" do
      let(:data) { Dis::Model::Data.new(image, uploaded_file) }

      it "should store the data" do
        expect(Dis::Storage).to receive(:store).with("images", uploaded_file)
        data.store!
      end

      it "should return the hash" do
        expect(data.store!).to eq(hash)
      end
    end
  end
end