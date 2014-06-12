require 'shrouded/model/callbacks'
require 'shrouded/model/class_methods'

module Shrouded
  module Model
    extend ActiveSupport::Concern
    include Shrouded::Model::Callbacks

    def data
      @_cached_data ||= data_from(closest_data)
    end

    def data?
      raw_data? || stored_data?
    end

    def data=(new_data)
      self.raw_data = new_data
      @_cached_data = nil
      shrouded_set :content_hash, nil
      shrouded_set :content_length, detect_content_length
    end

    def file=(file)
      self.data = file
      shrouded_set :content_type, file.content_type
      shrouded_set :filename, file.original_filename
    end

    private

    def shrouded_set(attribute_name, value)
      self[shrouded_attribute(attribute_name)] = value
    end

    def shrouded_get(attribute_name)
      self[shrouded_attribute(attribute_name)]
    end

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
      if raw_data?
        raw_data
      elsif stored_data?
        stored_data
      end
    end

    def detect_content_length
      if raw_data.respond_to?(:length)
        raw_data.length
      else
        data.try(&:length).to_i
      end
    end

    def raw_data?
      raw_data ? true : false
    end

    def raw_data
      @raw_data
    end

    def raw_data=(new_data)
      @raw_data = new_data
    end

    def stored_data?
      !shrouded_get(:content_hash).blank?
    end

    def stored_data
      Shrouded::Storage.get(shrouded_type, shrouded_get(:content_hash))
    end
  end
end