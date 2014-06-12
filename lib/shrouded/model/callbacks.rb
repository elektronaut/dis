module Shrouded
  module Model
    module Callbacks
      extend ActiveSupport::Concern

      included do
        before_save :store_data
        after_save :cleanup_data
        after_destroy :delete_data
      end

      private

      def cleanup_data
        if previous_hash = changes[shrouded_attribute(:content_hash)].try(&:first)
          delete_data_if_unused(previous_hash)
        end
      end

      def delete_data
        delete_data_if_unused(shrouded_get(:content_hash))
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

      def store_data
        if raw_data?
          shrouded_set :content_hash, Shrouded::Storage.store(
            shrouded_type,
            raw_data
          )
        end
      end
    end
  end
end
