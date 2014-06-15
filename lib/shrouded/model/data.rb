# encoding: utf-8

module Shrouded
  module Model
    class Data
      def initialize(record, raw=nil)
        @record = record
        @raw = raw
      end

      def ==(comp)
        # TODO: This can be made faster by
        # comparing hashes for stored objects.
        comp.read == read
      end

      def any?
        raw? || stored?
      end

      def read
        @cached ||= read_from(closest)
      end

      def changed?
        raw?
      end

      def content_length
        if raw? && raw.respond_to?(:length)
          raw.length
        else
          read.try(&:length).to_i
        end
      end

      def expire(hash)
        unless @record.class.where(
          @record.class.shrouded_attributes[:content_hash] => hash
        ).any?
          Shrouded::Storage.delete(storage_type, hash)
        end
      end

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