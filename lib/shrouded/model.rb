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

    def data
      @_cached_data ||= data_from(closest_data)
    end

    def data=(new_data)
      @_raw_data = new_data
      @_cached_data = nil
      self[shrouded_attribute(:content_hash)] = nil
      self[shrouded_attribute(:content_length)] = detect_content_length
    end

    def data?
      (@_raw_data || !self[shrouded_attribute(:content_hash)].blank?) ? true : false
    end

    def file=(new_data)
      self.data = new_data
      self[shrouded_attribute(:content_type)] = new_data.content_type
      self[shrouded_attribute(:filename)] = new_data.original_filename
    end

    private

    def shrouded_attribute(attribute_name)
      self.class.shrouded_attributes[attribute_name]
    end

    def shrouded_type
      self.class.shrouded_type
    end

    def data_from(object)
      return nil unless object
      if object.respond_to?(:body)
        object.body
      elsif object.respond_to?(:read)
        object.rewind
        object.read
      else
        object
      end
    end

    def closest_data
      if @_raw_data
        @_raw_data
      elsif !self[shrouded_attribute(:content_hash)].blank?
        stored_data
      end
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

    def detect_content_length
      if @_raw_data.respond_to?(:length)
        @_raw_data.length
      else
        data.try(&:length).to_i
      end
    end

    def stored_data
      Shrouded::Storage.get(shrouded_type, self[shrouded_attribute(:content_hash)])
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
      if @_raw_data
        self[shrouded_attribute(:content_hash)] = Shrouded::Storage.store(
          shrouded_type,
          @_raw_data
        )
      end
    end
  end
end