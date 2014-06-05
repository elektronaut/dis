module BlobDispenser
  class Layer
    attr_reader :connection, :delayed

    def initialize(connection, options={})
      options = default_options.merge(options)
      @connection = connection
      @delayed = options[:delayed]
    end

    def delayed?
      @delayed
    end

    def immediate?
      !delayed?
    end

    private

    def default_options
      { delayed: false }
    end
  end
end
