module Shrouded
  module Model
    extend ActiveSupport::Concern

    included do
      before_save :store_data
      after_save :cleanup_data
      after_destroy :delete_data
    end

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

    def data=(new_data)
      @shrouded_data = new_data
      self.content_type = new_data.content_type
      self.content_length = new_data.length
      self.filename = new_data.original_filename
    end

    private

    def shrouded_attribute(attribute_name)
      self.class.shrouded_attributes[attribute_name]
    end

    def shrouded_type
      self.class.shrouded_type
    end

    def delete_data_if_unused(hash)
      unless self.class.where(
        shrouded_attribute(:content_hash) => hash
      ).any?
        Shrouded::Storage.delete(
          shrouded_type,
          hash
        )
      end
    end

    def cleanup_data
      if previous_hash = changes[shrouded_attribute(:content_hash)].try(&:first)
        delete_data_if_unused(previous_hash)
      end
    end

    def delete_data
      delete_data_if_unused(self[shrouded_attribute(:content_hash)])
    end

    def store_data
      if @shrouded_data
        self[shrouded_attribute(:content_hash)] = Shrouded::Storage.store(
          shrouded_type,
          @shrouded_data
        )
      end
    end
  end
end