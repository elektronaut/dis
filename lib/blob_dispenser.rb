# encoding: utf-8

require "fog"
require "blob_dispenser/engine"
require "blob_dispenser/errors"
require "blob_dispenser/layer"
require "blob_dispenser/layers"

module BlobDispenser
  class << self
    def layers
      @layers ||= BlobDispenser::Layers.new
    end
  end
end
