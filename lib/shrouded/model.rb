module Shrouded
  module Model
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def shrouded_attributes
        default_shrouded_attributes.merge(@shrouded_attributes || {})
      end

      private

      def set_shrouded_attributes(new_attributes)
        @shrouded_attributes = new_attributes
      end

      def default_shrouded_attributes
        {
          content_hash: :content_hash,
          content_length: :content_length,
          content_type: :content_type,
          filename: :filename
        }
      end
    end
  end
end