# frozen_string_literal: true

module Dis
  # = Dis Layers
  #
  # Represents a filterable collection of {Dis::Layer} instances.
  # Supports chained filtering by layer properties.
  #
  # @example
  #   Dis::Storage.layers.delayed.writeable.each { |l| ... }
  class Layers
    include Enumerable

    # @param layers [Array<Dis::Layer>] initial layers
    def initialize(layers = [])
      @layers = layers
    end

    # Adds a layer to the collection.
    delegate :<<, to: :@layers

    # Clears all layers from the collection.
    #
    # @return [void]
    def clear!
      @layers = []
    end

    # Iterates over the layers.
    def each(&block)
      @layers.each { |layer| block.call(layer) }
    end

    # Returns a new instance containing only the delayed layers.
    #
    # @return [Dis::Layers]
    def delayed
      self.class.new select(&:delayed?)
    end

    # Returns true if one or more delayed layers exist.
    #
    # @return [Boolean]
    def delayed?
      any?(&:delayed?)
    end

    # Returns a new instance containing only the immediate layers.
    #
    # @return [Dis::Layers]
    def immediate
      self.class.new select(&:immediate?)
    end

    # Returns true if one or more immediate layers exist.
    #
    # @return [Boolean]
    def immediate?
      any?(&:immediate?)
    end

    # Returns a new instance containing only the readonly layers.
    #
    # @return [Dis::Layers]
    def readonly
      self.class.new select(&:readonly?)
    end

    # Returns true if one or more readonly layers exist.
    #
    # @return [Boolean]
    def readonly?
      any?(&:readonly?)
    end

    # Returns a new instance containing only the writeable layers.
    #
    # @return [Dis::Layers]
    def writeable
      self.class.new select(&:writeable?)
    end

    # Returns true if one or more writeable layers exist.
    #
    # @return [Boolean]
    def writeable?
      any?(&:writeable?)
    end

    # Returns a new instance containing only the cache layers.
    #
    # @return [Dis::Layers]
    def cache
      self.class.new select(&:cache?)
    end

    # Returns true if one or more cache layers exist.
    #
    # @return [Boolean]
    def cache?
      any?(&:cache?)
    end

    # Returns a new instance containing only the non-cache layers.
    #
    # @return [Dis::Layers]
    def non_cache
      self.class.new reject(&:cache?)
    end

    # Returns true if one or more non-cache layers exist.
    #
    # @return [Boolean]
    def non_cache?
      any? { |l| !l.cache? }
    end
  end
end
