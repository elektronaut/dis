# encoding: utf-8

module BlobDispenser
  class Layers
    include Enumerable

    def initialize(layers=[])
      @layers = layers
    end

    def <<(layer)
      @layers << layer
    end

    def each
      @layers.each { |layer| yield layer }
    end

    def delayed
      self.class.new select { |layer| layer.delayed? }
    end

    def delayed?
      delayed.any?
    end

    def immediate
      self.class.new select { |layer| layer.immediate? }
    end

    def immediate?
      immediate.any?
    end

    def readonly
      self.class.new select { |layer| layer.readonly? }
    end

    def readonly?
      readonly.any?
    end

    def writeable
      self.class.new select { |layer| layer.writeable? }
    end

    def writeable?
      writeable.any?
    end
  end
end