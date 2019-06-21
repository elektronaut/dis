# frozen_string_literal: true

require "spec_helper"

describe Dis::Validations::DataPresence do
  subject { image.errors[:data] }

  let(:hash) { "8843d7f92416211de9ebb963ff4ce28125932878" }
  let(:root_path) { Rails.root.join("tmp", "spec") }
  let(:file_path) { "../../../support/fixtures/file.txt" }
  let(:file) { File.open(File.expand_path(file_path, __FILE__)) }
  let(:uploaded_file) { Rack::Test::UploadedFile.new(file, "text/plain") }
  let(:image) { ImageWithValidations.new }
  let(:layer) do
    Dis::Layer.new(Fog::Storage.new(provider: "Local", local_root: root_path))
  end

  before do
    Dis::Storage.layers.clear!
    Dis::Storage.layers << layer
    image.valid?
  end

  after do
    FileUtils.rm_rf(root_path) if File.exist?(root_path)
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

  context "when data exists in storage" do
    let(:existing_image) do
      ImageWithValidations.create(data: uploaded_file, accept: true)
    end
    let(:image) { ImageWithValidations.find(existing_image.id) }

    it { is_expected.to eq([]) }
  end
end
