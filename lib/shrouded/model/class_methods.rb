# encoding: utf-8

module Shrouded
  module Model
    module ClassMethods
      # Returns the mapping of attribute names.
      def shrouded_attributes
        default_shrouded_attributes.merge(@shrouded_attributes || {})
      end

      # Sets the current mapping of attribute names. Use this if you want to
      # override the attributes and database columns that Shrouded will use.
      #
      #   class Document < ActiveRecord::Base
      #     include Shrouded::Model
      #     self.shrouded_attributes = { filename: :my_custom_filename }
      #   end
      def shrouded_attributes=(new_attributes)
        @shrouded_attributes = new_attributes
      end

      # Returns the storage type name, which Shrouded will use for
      # directory scoping. Defaults to the name of the database table.
      #
      #   class Document < ActiveRecord::Base; end
      #   Document.shrouded_type # => "documents"
      def shrouded_type
        @shrouded_type || self.table_name
      end

      # Sets the storage type name.
      #
      # Take care not to set the same name for multiple models, this will
      # cause data loss when a record is destroyed.
      def shrouded_type=(new_type)
        @shrouded_type = new_type
      end

      # Adds a presence validation on the +data+ attribute.
      #
      # This is better than using `validates :data, presence: true`, since
      # that would cause it to load the data from storage on each save.
      #
      #   class Document < ActiveRecord::Base
      #     include Shrouded::Model
      #     validates_data_presence
      #   end
      def validates_data_presence
        validates_with Shrouded::Validations::DataPresence
      end

      # Returns the default attribute names.
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