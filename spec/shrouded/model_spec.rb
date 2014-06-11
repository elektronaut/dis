require 'spec_helper'

describe Shrouded::Model do

  class Image < ActiveRecord::Base
    shrouded_model
  end

  class WithCustomAttributes < ActiveRecord::Base
    shrouded_model attributes: { filename: :uploaded_filename, content_type: :type }
  end

  subject { Image }

  describe "#shrouded_attributes" do
    subject(:attributes) { model.shrouded_attributes }

    context "with no attributes specified" do
      let(:model) { Image }
      it "should return the default attributes" do
        expect(attributes).to eq({
          content_hash: :content_hash,
          content_length: :content_length,
          content_type: :content_type,
          filename: :filename
        })
      end
    end

    context "with custom attributes" do
      let(:model) { WithCustomAttributes }
      it "should return the attributes" do
        expect(attributes).to eq({
          content_hash: :content_hash,
          content_length: :content_length,
          content_type: :type,
          filename: :uploaded_filename
        })
      end
    end
  end
end