# encoding: utf-8

module Shrouded
  module Errors
    class Error < StandardError; end
    class ReadOnlyError < Shrouded::Errors::Error; end
    class NoLayersError < Shrouded::Errors::Error; end
    class NotFoundError < Shrouded::Errors::Error; end
  end
end