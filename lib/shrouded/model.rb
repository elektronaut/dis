require 'shrouded/model/callbacks'
require 'shrouded/model/class_methods'

module Shrouded
  module Model
    extend ActiveSupport::Concern
    include Shrouded::Model::Callbacks

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

    def file=(file)
      self.data = file
      self[shrouded_attribute(:content_type)] = file.content_type
      self[shrouded_attribute(:filename)] = file.original_filename
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
  end
end