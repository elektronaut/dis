# encoding: utf-8

require "fog"
require "shrouded/engine"
require "shrouded/errors"
require "shrouded/layer"
require "shrouded/layers"

module Shrouded
  class << self
    def layers
      @layers ||= Shrouded::Layers.new
    end
  end
end
