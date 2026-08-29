# frozen_string_literal: true

require "spec_helper"

describe Dis::Controller, type: :request do
  let(:root_path) { Rails.root.join("tmp/spec") }
  # Position-dependent so a wrong offset cannot compare equal.
  let(:content) { (1..5_000).map { |i| format("%05d\n", i) }.join }
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
    allow(Dis::ResponseBody).to receive(:new).and_wrap_original do |m, *args, **opts|
      m.call(*args, **opts).tap { |body| bodies << body }
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

  describe "range requests" do
    def get_range(range, path: "/images/#{image.id}", headers: {})
      get(path, headers: { "Range" => range }.merge(headers).compact)
    end

    it "advertises range support on a normal response" do
      get("/images/#{image.id}")
      expect(response.headers["Accept-Ranges"]).to eq("bytes")
    end

    context "with a satisfiable range" do
      before { get_range("bytes=10-29") }

      it "responds with partial content" do
        expect(response).to have_http_status(:partial_content)
      end

      it "sends only the requested bytes" do
        expect(response.body).to eq(content[10..29])
      end

      it "sets Content-Range" do
        expect(response.headers["Content-Range"])
          .to eq("bytes 10-29/#{content.bytesize}")
      end

      it "sets Content-Length to the range length" do
        expect(response.headers["Content-Length"].to_i).to eq(20)
      end

      it "closes the file when the response is done" do
        expect(bodies.last).to be_closed
      end
    end

    context "with an open-ended range" do
      before { get_range("bytes=29990-") }

      it "sends through to the end of the file" do
        expect(response.body).to eq(content[29_990..])
      end

      it "sets Content-Range" do
        expect(response.headers["Content-Range"])
          .to eq("bytes 29990-29999/#{content.bytesize}")
      end
    end

    context "with a suffix range" do
      before { get_range("bytes=-10") }

      it "sends the final bytes" do
        expect(response.body).to eq(content[-10..])
      end

      it "sets Content-Range" do
        expect(response.headers["Content-Range"])
          .to eq("bytes 29990-29999/#{content.bytesize}")
      end
    end

    context "with a range larger than the file" do
      before { get_range("bytes=0-99999") }

      it "clamps to the file size" do
        expect(response.body).to eq(content)
      end

      it "sets Content-Range to the whole file" do
        expect(response.headers["Content-Range"])
          .to eq("bytes 0-29999/#{content.bytesize}")
      end
    end

    context "with multiple ranges" do
      before { get_range("bytes=0-9,20-29") }

      def boundary
        response.headers["Content-Type"][/boundary=(\S+)/, 1]
      end

      def parts
        response.body.split("\r\n--#{boundary}").filter_map do |part|
          next if part.empty? || part.start_with?("--")

          head, _, payload = part.partition("\r\n\r\n")
          { head: head.split("\r\n").reject(&:empty?), payload: }
        end
      end

      it "responds with partial content" do
        expect(response).to have_http_status(:partial_content)
      end

      it "responds as multipart/byteranges" do
        expect(response.headers["Content-Type"])
          .to match(%r{\Amultipart/byteranges; boundary=\h{32}\z})
      end

      it "does not set a top-level Content-Range" do
        expect(response.headers["Content-Range"]).to be_nil
      end

      it "sets Content-Length to the actual body size" do
        expect(response.headers["Content-Length"].to_i)
          .to eq(response.body.bytesize)
      end

      it "sends one part per range" do
        expect(parts.length).to eq(2)
      end

      it "sends the bytes of each range" do
        expect(parts.pluck(:payload))
          .to eq([content[0..9], content[20..29]])
      end

      it "sets Content-Range on each part" do
        expect(parts.map { |p| p[:head].grep(/Content-Range/).first })
          .to eq(["Content-Range: bytes 0-9/#{content.bytesize}",
                  "Content-Range: bytes 20-29/#{content.bytesize}"])
      end

      it "sets the record's content type on each part" do
        expect(parts.map { |p| p[:head].grep(/Content-Type/).first })
          .to eq(["Content-Type: text/plain"] * 2)
      end

      it "terminates the multipart body" do
        expect(response.body).to end_with("--#{boundary}--\r\n")
      end

      it "closes the file when the response is done" do
        expect(bodies.last).to be_closed
      end
    end

    context "with more ranges than Rack will parse" do
      def many_ranges
        (0...200).map { |i| "#{i}-#{i}" }.join(",")
      end

      before { get_range("bytes=#{many_ranges}") }

      it "ignores the range and responds with success" do
        expect(response).to have_http_status(:ok)
      end

      it "sends the whole file" do
        expect(response.body).to eq(content)
      end
    end

    context "with an unsatisfiable range" do
      before { get_range("bytes=99999-100000") }

      it "responds with 416" do
        expect(response).to have_http_status(:range_not_satisfiable)
      end

      it "reports the full size in Content-Range" do
        expect(response.headers["Content-Range"])
          .to eq("bytes */#{content.bytesize}")
      end

      it "sends no body" do
        expect(response.body).to eq("")
      end

      it "does not leak an open file" do
        expect(bodies).to be_empty
      end
    end

    context "with an unparseable range" do
      before { get_range("bytes=abc") }

      it "responds with success" do
        expect(response).to have_http_status(:ok)
      end

      it "sends the whole file" do
        expect(response.body).to eq(content)
      end
    end
  end

  describe "If-Range" do
    def current_etag
      get("/images/#{image.id}/cached")
      response.headers["ETag"]
    end

    def get_cached(if_range)
      get("/images/#{image.id}/cached",
          headers: { "Range" => "bytes=10-29", "If-Range" => if_range })
    end

    it "serves the range when the validator matches" do
      get_cached(current_etag)
      expect(response).to have_http_status(:partial_content)
    end

    it "sends the matched range" do
      get_cached(current_etag)
      expect(response.body).to eq(content[10..29])
    end

    it "serves the whole file when the validator does not match" do
      get_cached('"stale"')
      expect(response).to have_http_status(:ok)
    end

    it "sends the whole body when the validator does not match" do
      get_cached('"stale"')
      expect(response.body).to eq(content)
    end

    it "ignores the range when there is no validator to compare" do
      get("/images/#{image.id}",
          headers: { "Range" => "bytes=10-29", "If-Range" => '"whatever"' })
      expect(response).to have_http_status(:ok)
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
