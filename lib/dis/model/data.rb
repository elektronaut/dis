# frozen_string_literal: true

module Dis
  module Model
    # = Dis Model Data
    #
    # Facilitates communication between the model and the storage,
    # and holds any newly assigned data before the record is saved.
    class Data
      # @param record [ActiveRecord::Base] the model instance
      # @param raw [File, IO, String, nil] newly assigned data
      def initialize(record, raw = nil)
        @record = record
        @raw = raw
      end

      # Returns true if two Data objects represent the same data.
      #
      # @param other [Dis::Model::Data, #read, Object] the object to
      #   compare
      # @return [Boolean]
      def ==(other)
        if !raw? && other.is_a?(self.class) && !other.changed?
          content_hash == other.content_hash
        elsif other.respond_to?(:read)
          other.read == read
        else
          false
        end
      end

      # Returns true if data exists either in memory or in storage.
      #
      # @return [Boolean]
      def any?
        raw? || stored?
      end

      # Returns the data as a binary string.
      #
      # @return [String, nil]
      def read
        @read ||= read_from(closest)
      end

      # Will be true if data has been explicitly set.
      #
      # @return [Boolean]
      #
      # @example
      #   Dis::Model::Data.new(record).changed? # => false
      #   Dis::Model::Data.new(record, file).changed? # => true
      def changed?
        raw?
      end

      # Returns the length of the data in bytes.
      #
      # @return [Integer]
      def content_length
        if raw? && raw.respond_to?(:length)
          raw.length
        else
          read.try(&:length).to_i
        end
      end

      # Expires a data object from the storage if it's no longer
      # being used by existing records. This is triggered from
      # callbacks on the record whenever they are changed or
      # destroyed.
      #
      # @param hash [String] the content hash to expire
      # @return [void]
      def expire(hash)
        return if hash.blank?

        unless @record.class.where(
          @record.class.dis_attributes[:content_hash] => hash
        ).any?
          Dis::Storage.delete(storage_type, hash)
        end
      end

      # Stores the data and returns the content hash.
      #
      # @return [String] the SHA1 content hash
      # @raise [Dis::Errors::NoDataError] if no data has been
      #   assigned
      def store!
        raise Dis::Errors::NoDataError unless raw?

        Dis::Storage.store(storage_type, raw)
      end

      # Clears cached data and tempfiles, allowing them to be
      # garbage collected. Subsequent calls to +read+ or +tempfile+
      # will re-fetch from storage.
      #
      # @return [void]
      def reset_read_cache!
        @read = nil
        return unless @tempfile

        @tempfile.close!
        @tempfile = nil
      end

      # Returns the file path to the data. Prefers a local storage
      # path to avoid unnecessary copies, falls back to a tempfile.
      #
      # @return [String]
      def file_path
        local_path || tempfile.path
      end

      # Writes the data to a temporary file.
      #
      # @return [Tempfile]
      def tempfile
        unless @tempfile
          @tempfile = Tempfile.new(binmode: true)
          @tempfile.write(@read || read_from(closest))
          @tempfile.open
        end
        @tempfile
      end

      protected

      def content_hash
        @record[@record.class.dis_attributes[:content_hash]]
      end

      private

      def closest
        if raw?
          raw
        elsif stored?
          stored
        end
      end

      def raw?
        raw ? true : false
      end

      def read_from(object)
        return nil unless object

        if object.respond_to?(:body)
          object.body
        elsif object.respond_to?(:read)
          rewind_and_read(object)
        else
          object
        end
      end

      def rewind_and_read(object)
        object.rewind
        response = object.read
        object.rewind
        response
      end

      def storage_type
        @record.class.dis_type
      end

      def stored?
        content_hash.present? &&
          (@record.dis_stored? ||
           Dis::Storage.exists?(storage_type, content_hash))
      end

      def stored
        Dis::Storage.get(storage_type, content_hash)
      end

      def local_path
        return if raw?

        Dis::Storage.file_path(storage_type, content_hash)
      end

      attr_reader :raw
    end
  end
end
