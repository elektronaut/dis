# encoding: utf-8

require 'dis/model/class_methods'
require 'dis/model/data'

module Dis
  # = Dis Model
  #
  # ActiveModel extension for the model holding your data. To use it,
  # simply include the module in your model:
  #
  #   class Document < ActiveRecord::Base
  #     include Dis::Model
  #   end
  #
  # You'll need to define a few attributes in your database table.
  # Here's a minimal migration:
  #
  #   create_table :documents do |t|
  #     t.string  :content_hash
  #     t.string  :content_type
  #     t.integer :content_length
  #     t.string  :filename
  #   end
  #
  # You can override the names of any of these by setting
  # <tt>dis_attributes</tt>.
  #
  #   class Document < ActiveRecord::Base
  #     include Dis::Model
  #     self.dis_attributes = {
  #       filename:       :my_filename,
  #       content_length: :filesize
  #     }
  #   end
  #
  # == Usage
  #
  # To save a file, simply assign to the <tt>file</tt> attribute.
  #
  #   document = Document.create(file: params.permit(:file))
  #
  # <tt>content_type</tt> and <tt>filename</tt> will automatically be set if
  # the supplied object quacks like a file. <tt>content_length</tt> will always
  # be set. <tt>content_hash</tt> won't be set until the record is being saved.
  #
  # If you don't care about filenames and content types and just want to store
  # a binary blob, you can also just set the <tt>data</tt> attribute.
  #
  #   my_data = File.read('document.pdf')
  #   document.update(data: my_data)
  #
  # The data won't be stored until the record is saved, and not unless
  # the record is valid.
  #
  # To retrieve your data, simply read the <tt>data</tt> attribute. The file
  # will be lazily loaded from the store on demand and cached in memory as long
  # as the record stays in scope.
  #
  #   my_data = document.data
  #
  # Destroying a record will delete the file from the store, unless another
  # record also refers to the same hash. Similarly, stale files will be purged
  # when content changes.
  #
  # == Validations
  #
  # No validation is performed by default. If you want to ensure that data is
  # present, use the <tt>validates_data_presence</tt> method.
  #
  #   class Document < ActiveRecord::Base
  #     include Dis::Model
  #     validates_data_presence
  #   end
  #
  # If you want to validate content types, size or similar, simply use standard
  # Rails validations on the metadata attributes:
  #
  #   validates :content_type, presence: true, format: /\Aapplication\/(x\-)?pdf\z/
  #   validates :filename, presence: true, format: /\A[\w_\-\.]+\.pdf\z/i
  #   validates :content_length, numericality: { less_than: 5.megabytes }
  module Model
    extend ActiveSupport::Concern

    included do
      before_save :store_data
      after_save :cleanup_data
      after_destroy :delete_data
    end

    # Returns the data as a binary string, or nil if no data has been set.
    def data
      dis_data.read
    end

    # Returns true if data is set.
    def data?
      dis_data.any?
    end

    # Assigns new data. This also sets <tt>content_length</tt>, and resets
    # <tt>content_hash</tt> to nil.
    def data=(new_data)
      new_data = Dis::Model::Data.new(self, new_data)
      attribute_will_change!('data') unless new_data == dis_data
      @dis_data = new_data
      dis_set :content_hash, nil
      dis_set :content_length, dis_data.content_length
    end

    # Returns true if the data has been changed since the object was last saved.
    def data_changed?
      changes.include?('data')
    end

    # Assigns new data from an uploaded file. In addition to the actions
    # performed by <tt>data=</tt>, this will set <tt>content_type</tt> and
    # <tt>filename</tt>.
    def file=(file)
      self.data = file
      dis_set :content_type, file.content_type
      dis_set :filename, file.original_filename
    end

    private

    def cleanup_data
      if previous_hash = changes[dis_attribute(:content_hash)].try(&:first)
        dis_data.expire(previous_hash)
      end
    end

    def delete_data
      dis_data.expire(dis_get(:content_hash))
    end

    def store_data
      if dis_data.changed?
        dis_set :content_hash, dis_data.store!
      end
    end

    def dis_get(attribute_name)
      self[dis_attribute(attribute_name)]
    end

    def dis_data
      @dis_data ||= Dis::Model::Data.new(self)
    end

    def dis_set(attribute_name, value)
      self[dis_attribute(attribute_name)] = value
    end

    def dis_attribute(attribute_name)
      self.class.dis_attributes[attribute_name]
    end
  end
end