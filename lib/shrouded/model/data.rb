# encoding: utf-8

module Shrouded
  module Model
    # = Shrouded Model Data
    #
    # Facilitates communication between the model and the storage,
    # and holds any newly assigned data before the record is saved.
    class Data
      def initialize(record, raw=nil)
        @record = record
        @raw = raw
      end

      # Returns true if two Data objects represent the same data.
      def ==(comp)
        # TODO: This can be made faster by
        # comparing hashes for stored objects.
        comp.read == read
      end

      # Returns true if data exists either in memory or in storage.
      def any?
        raw? || stored?
      end

      # Returns the data as a binary string.
      def read
        @cached ||= read_from(closest)
      end

      # Will be true if data has been explicitely set.
      #
      #   Shrouded::Model::Data.new(record).changed? # => false
      #   Shrouded::Model::Data.new(record, new_file).changed? # => true
      def changed?
        raw?
      end

      # Returns the length of the data.
      def content_length
        if raw? && raw.respond_to?(:length)
          raw.length
        else
          read.try(&:length).to_i
        end
      end

      # Expires a data object from the storage if it's no longer being used
      # by existing records. This is triggered from callbacks on the record
      # whenever they are changed or destroyed.
      def expire(hash)
        unless @record.class.where(
          @record.class.shrouded_attributes[:content_hash] => hash
        ).any?
          Shrouded::Storage.delete(storage_type, hash)
        end
      end

      # Stores the data. Returns a hash of the content for reference.
      def store!
        raise Shrouded::Errors::NoDataError unless raw?
        Shrouded::Storage.store(storage_type, raw)
      end

      private

      def closest
        if raw?
          raw
        elsif stored?
          stored
        end
      end

      def content_hash
        @record[@record.class.shrouded_attributes[:content_hash]]
      end

      def raw?
        raw ? true : false
      end

      def read_from(object)
        return nil unless object
        if object.respond_to?(:body)
          object.body
        elsif object.respond_to?(:read)
          object.rewind
          response = object.read
          object.rewind
          response
        else
          object
        end
      end

      def storage_type
        @record.class.shrouded_type
      end

      def stored?
        !content_hash.blank?
      end

      def stored
        Shrouded::Storage.get(
          storage_type,
          content_hash
        )
      end

      def raw
        @raw
      end
    end
  end
end