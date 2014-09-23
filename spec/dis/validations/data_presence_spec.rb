# encoding: utf-8

require 'spec_helper'

describe Dis::Validations::DataPresence do
  let(:hash)          { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:root_path)     { Rails.root.join('tmp', 'spec') }
  let(:file)          { File.open(File.expand_path("../../../support/fixtures/file.txt", __FILE__)) }
  let(:uploaded_file) { Rack::Test::UploadedFile.new(file, 'text/plain') }
  let(:layer)         { Dis::Layer.new(Fog::Storage.new({provider: 'Local', local_root: root_path})) }
  let(:image)         { ImageWithValidations.new }

  before do
    Dis::Storage.layers << layer
  end

  after do
    FileUtils.rm_rf(root_path) if File.exists?(root_path)
    Dis::Storage.layers.clear!
  end

  subject { image.errors[:data] }
  before { image.valid? }

  context "with no data" do
    it { is_expected.to include("can't be blank") }
  end

  context "when data is set" do
    let(:image) { ImageWithValidations.new(data: uploaded_file) }
    it { is_expected.to eq([]) }
  end

  context "when data exists in storage" do
    let(:existing_image) { ImageWithValidations.create(data: uploaded_file, accept: true) }
    let(:image) { ImageWithValidations.find(existing_image.id) }
    it { is_expected.to eq([]) }
  end
end