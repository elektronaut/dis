module Shrouded
  module Model
    class Data
      attr_reader :record, :raw

      def initialize(record, raw=nil)
        @record = record
        @raw = raw
      end

      def any?
        raw? || stored?
      end

      def cached
        @cached ||= read_from(closest)
      end

      def changed?
        raw?
      end

      def content_length
        if raw? && raw.respond_to?(:length)
          raw.length
        else
          cached.try(&:length).to_i
        end
      end

      def expire(hash)
        unless record.class.where(
          record.class.shrouded_attributes[:content_hash] => hash
        ).any?
          Shrouded::Storage.delete(
            record.class.shrouded_type,
            hash
          )
        end
      end

      def raw?
        raw ? true : false
      end

      def store!
        Shrouded::Storage.store(
          record.class.shrouded_type,
          raw
        )
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
        record[record.class.shrouded_attributes[:content_hash]]
      end

      def read_from(object)
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

      def stored?
        !content_hash.blank?
      end

      def stored
        Shrouded::Storage.get(
          record.class.shrouded_type,
          content_hash
        )
      end
    end
  end
end