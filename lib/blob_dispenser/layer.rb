module BlobDispenser
  class Layer
    attr_reader :connection

    def initialize(connection, options={})
      options     = default_options.merge(options)
      @connection = connection
      @delayed    = options[:delayed]
      @readonly   = options[:readonly]
      @public     = options[:public]
      @path       = options[:path]
    end

    def delayed?
      @delayed
    end

    def immediate?
      !delayed?
    end

    def public?
      @public
    end

    def readonly?
      @readonly
    end

    def writeable?
      !readonly?
    end

    def store(hash, file)
      raise BlobDispenser::Errors::ReadOnlyError if readonly?
      return get(hash) if exists?(hash)
      directory!(hash).files.create(
        key:    key_component(hash),
        body:   file,
        public: public?
      )
    end

    def exists?(hash)
      directory(hash) &&
      directory(hash).files.head(key_component(hash))
    end

    def get(hash)
      if dir = directory(hash)
        dir.files.get(key_component(hash))
      end
    end

    def delete(hash)
      raise BlobDispenser::Errors::ReadOnlyError if readonly?
      return false unless exists?(hash)
      get(hash).destroy
    end

    private

    def directory_component(hash)
      [path, hash[0...2]].compact.join('/')
    end

    def key_component(hash)
      hash[2..hash.length]
    end

    def directory(hash)
      connection.directories.get(directory_component(hash))
    end

    def directory!(hash)
      dir = directory(hash)
      dir ||= connection.directories.create(
        key:    directory_component(hash),
        public: public?
      )
      dir
    end

    def path
      @path && !@path.empty? ? @path : nil
    end

    def default_options
      { delayed: false, readonly: false, public: false, path: nil }
    end
  end
end
