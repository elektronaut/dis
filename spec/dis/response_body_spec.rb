# frozen_string_literal: true

require "spec_helper"

describe Dis::ResponseBody do
  subject(:response_body) { described_class.new(file) }

  let(:content) { "a" * 40_000 }
  let(:file) do
    f = Tempfile.create
    f.binmode
    f.write(content)
    f.rewind
    f
  end

  after do
    file.close unless file.closed?
    FileUtils.rm_f(file.path)
  end

  describe "#body" do
    it "returns the entire contents" do
      expect(response_body.body).to eq(content)
    end

    it "returns the contents again on a second call" do
      response_body.body
      expect(response_body.body).to eq(content)
    end
  end

  describe "#each" do
    subject(:chunks) { response_body.enum_for(:each).to_a }

    it "yields the entire contents" do
      expect(chunks.join).to eq(content)
    end

    it "yields more than one chunk" do
      expect(chunks.length).to be > 1
    end

    it "yields the contents after the file has been unlinked" do
      File.unlink(file.path)
      expect(chunks.join).to eq(content)
    end

    it "yields the contents after #body has been read" do
      response_body.body
      expect(chunks.join).to eq(content)
    end
  end

  describe "#close" do
    it "closes the file" do
      response_body.close
      expect(file).to be_closed
    end

    it "does not raise when called twice" do
      response_body.close
      expect { response_body.close }.not_to raise_error
    end

    it "reports the body as closed" do
      response_body.close
      expect(response_body).to be_closed
    end
  end

  describe "the Rack contract" do
    it "does not respond to to_path" do
      expect(response_body).not_to respond_to(:to_path)
    end

    it "does not respond to to_ary" do
      expect(response_body).not_to respond_to(:to_ary)
    end
  end
end
