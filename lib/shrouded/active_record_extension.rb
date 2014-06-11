module Shrouded
  module ActiveRecordExtension
    def shrouded_model(options={})
      include Shrouded::Model
      if options.has_key?(:attributes)
        set_shrouded_attributes(options[:attributes])
      end
      if options.has_key?(:type)
        set_shrouded_type(options[:type].to_s)
      end
    end
  end
end

class ActiveRecord::Base
  extend Shrouded::ActiveRecordExtension
end