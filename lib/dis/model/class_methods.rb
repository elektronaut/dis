# encoding: utf-8

module Dis
  module Model
    module ClassMethods
      # Returns the mapping of attribute names.
      def dis_attributes
        default_dis_attributes.merge(@dis_attributes ||= {})
      end

      # Sets the current mapping of attribute names. Use this if you want to
      # override the attributes and database columns that Dis will use.
      #
      #   class Document < ActiveRecord::Base
      #     include Dis::Model
      #     self.dis_attributes = { filename: :my_custom_filename }
      #   end
      def dis_attributes=(new_attributes)
        @dis_attributes = new_attributes
      end

      # Returns the storage type name, which Dis will use for
      # directory scoping. Defaults to the name of the database table.
      #
      #   class Document < ActiveRecord::Base; end
      #   Document.dis_type # => "documents"
      def dis_type
        @dis_type ||= table_name
      end

      # Sets the storage type name.
      #
      # Take care not to set the same name for multiple models, this will
      # cause data loss when a record is destroyed.
      def dis_type=(new_type)
        @dis_type = new_type
      end

      # Adds a presence validation on the +data+ attribute.
      #
      # This is better than using `validates :data, presence: true`, since
      # that would cause it to load the data from storage on each save.
      #
      #   class Document < ActiveRecord::Base
      #     include Dis::Model
      #     validates_data_presence
      #   end
      def validates_data_presence
        validates_with Dis::Validations::DataPresence
      end

      # Returns the default attribute names.
      def default_dis_attributes
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
