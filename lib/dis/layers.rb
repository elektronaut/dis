# encoding: utf-8

module Dis
  # = Dis Layers
  #
  # Represents a collection of layers.
  class Layers
    include Enumerable

    def initialize(layers=[])
      @layers = layers
    end

    # Adds a layer to the collection.
    def <<(layer)
      @layers << layer
    end

    # Clears all layers from the collection.
    def clear!
      @layers = []
    end

    # Iterates over the layers.
    def each
      @layers.each { |layer| yield layer }
    end

    # Returns a new instance containing only the delayed layers.
    def delayed
      self.class.new select { |layer| layer.delayed? }
    end

    # Returns true if one or more delayed layers exist.
    def delayed?
      delayed.any?
    end

    # Returns a new instance containing only the immediate layers.
    def immediate
      self.class.new select { |layer| layer.immediate? }
    end

    # Returns true if one or more immediate layers exist.
    def immediate?
      immediate.any?
    end

    # Returns a new instance containing only the readonly layers.
    def readonly
      self.class.new select { |layer| layer.readonly? }
    end

    # Returns true if one or more readonly layers exist.
    def readonly?
      readonly.any?
    end

    # Returns a new instance containing only the writeable layers.
    def writeable
      self.class.new select { |layer| layer.writeable? }
    end

    # Returns true if one or more writeable layers exist.
    def writeable?
      writeable.any?
    end
  end
end