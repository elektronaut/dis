module Shrouded
  module Model
    module ClassMethods
      def shrouded_attributes
        default_shrouded_attributes.merge(@shrouded_attributes || {})
      end

      def shrouded_type
        @shrouded_type || self.table_name
      end

      private

      def set_shrouded_attributes(new_attributes)
        @shrouded_attributes = new_attributes
      end

      def set_shrouded_type(new_type)
        @shrouded_type = new_type
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