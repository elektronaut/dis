# encoding: utf-8

module BlobDispenser
  module Errors
    class Error < StandardError; end
    class ReadOnlyError < BlobDispenser::Errors::Error; end
  end
end