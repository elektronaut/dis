# frozen_string_literal: true

require "spec_helper"

describe "send_dis_data in an ActionController::Live controller", type: :request do
  let(:root_path) { Rails.root.join("tmp/spec") }
  let(:content) { "foobar" * 5_000 }
  let(:layer) do
    Dis::Layer.new(Fog::Storage.new(provider: "Local", local_root: root_path))
  end
  let(:image) do
    Image.create!(data: content, filename: "file.txt",
                  content_type: "text/plain", accept: true)
  end

  before { Dis::Storage.layers << layer }

  after do
    FileUtils.rm_rf(root_path)
    Dis::Storage.layers.clear!
  end

  it "responds with success" do
    get live_image_path(image)
    expect(response).to have_http_status(:ok)
  end

  it "sends the data" do
    get live_image_path(image)
    expect(response.body).to eq(content)
  end

  context "when no layer stores the file locally" do
    before { allow(Dis::Storage).to receive(:file_path).and_return(nil) }

    it "sends the data" do
      get live_image_path(image)
      expect(response.body).to eq(content)
    end
  end
end
