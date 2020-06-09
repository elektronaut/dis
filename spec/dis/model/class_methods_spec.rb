# frozen_string_literal: true

require "spec_helper"

describe Dis::Model::ClassMethods do
  let(:with_custom_attributes) do
    Class.new(ApplicationRecord) do
      include Dis::Model
      self.dis_attributes = { filename: :uploaded_filename,
                              content_type: :type }
      self.dis_type = "custom"
    end
  end

  describe ".dis_attributes" do
    subject(:attributes) { model.dis_attributes }

    context "with no attributes specified" do
      let(:model) { Image }

      it "returns the default attributes" do
        expect(attributes).to eq(content_hash: :content_hash,
                                 content_length: :content_length,
                                 content_type: :content_type,
                                 filename: :filename)
      end
    end

    context "with custom attributes" do
      let(:model) { with_custom_attributes }

      it "returns the attributes" do
        expect(attributes).to eq(content_hash: :content_hash,
                                 content_length: :content_length,
                                 content_type: :type,
                                 filename: :uploaded_filename)
      end
    end
  end

  describe ".dis_type" do
    subject(:type) { model.dis_type }

    context "with no attributes specified" do
      let(:model) { Image }

      it "returns the table name" do
        expect(type).to eq("images")
      end
    end

    context "with custom attributes" do
      let(:model) { with_custom_attributes }

      it "returns the type" do
        expect(type).to eq("custom")
      end
    end
  end
end
