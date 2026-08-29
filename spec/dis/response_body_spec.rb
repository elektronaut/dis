# frozen_string_literal: true

require "spec_helper"

describe Dis::ResponseBody do
  subject(:response_body) { described_class.new(file) }

  # Position-dependent so a wrong offset cannot compare equal.
  let(:content) { (1..4_000).map { |i| format("%09d\n", i) }.join }
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

  describe "#length" do
    it "is the full size without a range" do
      expect(response_body.length).to eq(content.bytesize)
    end

    it "is the range size with a range" do
      body = described_class.new(file, range: 10..29)
      expect(body.length).to eq(20)
    end
  end

  describe "with a range" do
    subject(:response_body) { described_class.new(file, range: 10..20_009) }

    it "exposes the range" do
      expect(response_body.range).to eq(10..20_009)
    end

    describe "#body" do
      it "returns only the range" do
        expect(response_body.body).to eq(content[10..20_009])
      end

      it "returns the range again on a second call" do
        response_body.body
        expect(response_body.body).to eq(content[10..20_009])
      end
    end

    describe "#each" do
      subject(:chunks) { response_body.enum_for(:each).to_a }

      it "yields only the range" do
        expect(chunks.join).to eq(content[10..20_009])
      end

      it "yields exactly the range length" do
        expect(chunks.join.bytesize).to eq(20_000)
      end

      it "yields more than one chunk" do
        expect(chunks.length).to be > 1
      end

      it "yields the range after the file has been unlinked" do
        File.unlink(file.path)
        expect(chunks.join).to eq(content[10..20_009])
      end

      it "yields the range after #body has been read" do
        response_body.body
        expect(chunks.join).to eq(content[10..20_009])
      end
    end

    context "when the range reaches the end of the file" do
      subject(:response_body) do
        described_class.new(file, range: 39_990..39_999)
      end

      it "yields the final bytes" do
        expect(response_body.enum_for(:each).to_a.join)
          .to eq(content[39_990..39_999])
      end
    end

    context "when the range is a single byte" do
      subject(:response_body) { described_class.new(file, range: 5..5) }

      it "yields one byte" do
        expect(response_body.enum_for(:each).to_a.join).to eq(content[5])
      end
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
