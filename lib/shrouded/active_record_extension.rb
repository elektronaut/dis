module Shrouded
  module ActiveRecordExtension
    def shrouded_model(options={})
      include Shrouded::Model
      if options.has_key?(:attributes)
        set_shrouded_attributes(options[:attributes])
      end
    end
  end
end

class ActiveRecord::Base
  extend Shrouded::ActiveRecordExtension
end