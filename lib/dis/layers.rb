# frozen_string_literal: true

module Dis
  # = Dis Layers
  #
  # Represents a collection of layers.
  class Layers
    include Enumerable

    def initialize(layers = [])
      @layers = layers
    end

    # Adds a layer to the collection.
    delegate :<<, to: :@layers

    # Clears all layers from the collection.
    def clear!
      @layers = []
    end

    # Iterates over the layers.
    def each(&block)
      @layers.each { |layer| block.call(layer) }
    end

    # Returns a new instance containing only the delayed layers.
    def delayed
      self.class.new select(&:delayed?)
    end

    # Returns true if one or more delayed layers exist.
    def delayed?
      delayed.any?
    end

    # Returns a new instance containing only the immediate layers.
    def immediate
      self.class.new select(&:immediate?)
    end

    # Returns true if one or more immediate layers exist.
    def immediate?
      immediate.any?
    end

    # Returns a new instance containing only the readonly layers.
    def readonly
      self.class.new select(&:readonly?)
    end

    # Returns true if one or more readonly layers exist.
    def readonly?
      readonly.any?
    end

    # Returns a new instance containing only the writeable layers.
    def writeable
      self.class.new select(&:writeable?)
    end

    # Returns true if one or more writeable layers exist.
    def writeable?
      writeable.any?
    end

    # Returns a new instance containing only the cache layers.
    def cache
      self.class.new select(&:cache?)
    end

    # Returns true if one or more cache layers exist.
    def cache?
      cache.any?
    end

    # Returns a new instance containing only the non-cache layers.
    def non_cache
      self.class.new reject(&:cache?)
    end

    # Returns true if one or more non-cache layers exist.
    def non_cache?
      non_cache.any?
    end
  end
end
