# encoding: utf-8

require 'spec_helper'

describe Dis::SparseLayer do
  let(:type)        { 'sparse_test_files' }
  let(:root_path)   { Rails.root.join('tmp', 'spec') }
  let(:target_path) { root_path.join(type, '88', '43d7f92416211de9ebb963ff4ce28125932878') }
  let(:timestamp_path) { target_path.to_s + ".timestamp" }
  let(:hash)        { '8843d7f92416211de9ebb963ff4ce28125932878' }
  let(:file)        { File.open(File.expand_path("../../support/fixtures/file.txt", __FILE__)) }
  let(:connection)  { Fog::Storage.new({provider: 'Local', local_root: root_path}) }
  let(:layer)       { Dis::SparseLayer.new(connection) }

  after { FileUtils.rm_rf(root_path) if File.exist?(root_path) }

  before do
    Timecop.freeze(Time.local(2015))
  end

  after do
    Timecop.return
  end

  describe "#get" do
    context "when the timestamp file is missing" do
      before do
        layer.store(type, hash, file)
        File.unlink(timestamp_path)
        layer.get(type, hash)
      end

      it "create a timestamp file" do
        expect(File.exist?(timestamp_path)).to eq(true)
      end
    end

    context "when the file doesn't exist" do
      it "shouldn't create a timestamp file" do
        layer.get(type, hash)
        expect(File.exist?(timestamp_path)).to eq(false)
      end
    end

    context "when the existing timestamp is within 5 minutes" do
      it "shouldn't update the timestamp" do
        layer.store(type, hash, file)
        Timecop.travel(Time.local(2015) + 4.minutes)
        layer.get(type, hash)
        timestamp = DateTime.parse(File.read(timestamp_path))
        expect(timestamp).to eq(Time.local(2015))
      end
    end

    context "when the existing timestamp is older than 5 minutes" do
      it "should update the timestamp" do
        layer.store(type, hash, file)
        Timecop.travel(Time.local(2015) + 6.minutes)
        layer.get(type, hash)
        timestamp = DateTime.parse(File.read(timestamp_path))
        expect(timestamp).to eq(Time.local(2015) + 6.minutes)
      end
    end
  end

  describe "#store" do
    let(:result) { layer.store(type, hash, file) }

    context "with a file" do
      before { result }

      it "creates a timestamp file" do
        expect(File.exist?(timestamp_path)).to eq(true)
        timestamp = DateTime.parse(File.read(timestamp_path))
        expect(timestamp).to eq(DateTime.now)
      end
    end

    context "with a file and a path" do
      let(:layer)       { Dis::SparseLayer.new(connection, path: 'mypath') }
      let(:target_path) { root_path.join('mypath', type, '88', '43d7f92416211de9ebb963ff4ce28125932878') }
      let!(:result) { layer.store(type, hash, file) }

      it "creates a timestamp file" do
        expect(File.exist?(timestamp_path)).to eq(true)
        timestamp = DateTime.parse(File.read(timestamp_path))
        expect(timestamp).to eq(DateTime.now)
      end
    end
  end

  describe "#delete" do
    let(:result) { layer.delete(type, hash) }

    context "when the file exists" do
      before { layer.store(type, hash, file) }
      let!(:result) { layer.delete(type, hash) }

      it "deletes the timestamp file" do
        expect(File.exist?(timestamp_path)).to eq(false)
      end
    end
  end
end
