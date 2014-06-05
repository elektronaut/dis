module BlobDispenser
  class Layer
    attr_reader :connection

    def initialize(connection, options={})
      options = default_options.merge(options)
      @connection = connection
      @delayed = options[:delayed]
      @readonly = options[:readonly]
    end

    def delayed?
      @delayed
    end

    def immediate?
      !delayed?
    end

    def readonly?
      @readonly
    end

    def writeable?
      !readonly?
    end

    private

    def default_options
      { delayed: false, readonly: false }
    end
  end
end
