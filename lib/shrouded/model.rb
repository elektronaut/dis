require 'shrouded/model/class_methods'
require 'shrouded/model/data'

module Shrouded
  module Model
    extend ActiveSupport::Concern

    included do
      before_save :store_data
      after_save :cleanup_data
      after_destroy :delete_data
    end

    def data
      shrouded_data.cached
    end

    def data?
      shrouded_data.any?
    end

    def data=(new_data)
      @shrouded_data = Shrouded::Model::Data.new(self, new_data)
      shrouded_set :content_hash, nil
      shrouded_set :content_length, shrouded_data.content_length
    end

    def file=(file)
      self.data = file
      shrouded_set :content_type, file.content_type
      shrouded_set :filename, file.original_filename
    end

    private

    def cleanup_data
      if previous_hash = changes[shrouded_attribute(:content_hash)].try(&:first)
        shrouded_data.expire(previous_hash)
      end
    end

    def delete_data
      shrouded_data.expire(shrouded_get(:content_hash))
    end

    def store_data
      if shrouded_data.changed?
        shrouded_set :content_hash, shrouded_data.store!
      end
    end

    def shrouded_get(attribute_name)
      self[shrouded_attribute(attribute_name)]
    end

    def shrouded_data
      @shrouded_data ||= Shrouded::Model::Data.new(self)
    end

    def shrouded_set(attribute_name, value)
      self[shrouded_attribute(attribute_name)] = value
    end

    def shrouded_attribute(attribute_name)
      self.class.shrouded_attributes[attribute_name]
    end
  end
end