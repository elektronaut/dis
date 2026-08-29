# frozen_string_literal: true

require "spec_helper"

describe Dis::Controller, type: :request do
  let(:root_path) { Rails.root.join("tmp/spec") }
  let(:content) { "foobar" * 5_000 }
  let(:layer) do
    Dis::Layer.new(Fog::Storage.new(provider: "Local", local_root: root_path))
  end
  let(:image) do
    Image.create!(data: content, filename: "file.txt",
                  content_type: "text/plain", accept: true)
  end
  let(:bodies) { [] }

  before do
    Dis::Storage.layers << layer
    allow(Dis::ResponseBody).to receive(:new).and_wrap_original do |m, *args|
      m.call(*args).tap { |body| bodies << body }
    end
  end

  after do
    FileUtils.rm_rf(root_path)
    Dis::Storage.layers.clear!
  end

  describe "#send_dis_data" do
    before { get("/images/#{image.id}") }

    it "responds with success" do
      expect(response).to have_http_status(:ok)
    end

    it "sends the data" do
      expect(response.body).to eq(content)
    end

    it "sets a Content-Length matching the body" do
      expect(response.headers["Content-Length"].to_i).to eq(content.bytesize)
    end

    it "defaults the content type to the record's" do
      expect(response.media_type).to eq("text/plain")
    end

    it "defaults the filename to the record's" do
      expect(response.headers["Content-Disposition"]).to match("file.txt")
    end

    it "uses the given disposition" do
      expect(response.headers["Content-Disposition"]).to match("inline")
    end

    it "closes the file when the response is done" do
      expect(bodies.last).to be_closed
    end
  end

  describe "the default disposition" do
    before { get("/images/#{image.id}/download") }

    it "is attachment" do
      expect(response.headers["Content-Disposition"]).to match("attachment")
    end
  end

  context "when no layer stores the file locally" do
    before do
      image
      allow(Dis::Storage).to receive(:file_path).and_return(nil)
      get("/images/#{image.id}")
    end

    it "responds with success" do
      expect(response).to have_http_status(:ok)
    end

    it "sends the data" do
      expect(response.body).to eq(content)
    end

    it "closes the file when the response is done" do
      expect(bodies.last).to be_closed
    end
  end

  context "when the content is deleted while the response is written" do
    before do
      get("/images/#{image.id}")
      Dis::Storage.delete(Image.dis_type, image.content_hash)
    end

    it "still sends the data" do
      expect(response.body).to eq(content)
    end
  end

  context "when the data is missing" do
    before { Dis::Storage.delete(Image.dis_type, image.content_hash) }

    it "raises an error" do
      expect { get("/images/#{image.id}") }.to(
        raise_error(Dis::Errors::NotFoundError)
      )
    end
  end
end
