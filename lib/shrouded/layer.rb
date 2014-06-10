# encoding: utf-8

module Shrouded
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

    def store(type, hash, file)
      raise Shrouded::Errors::ReadOnlyError if readonly?
      store!(type, hash, file)
    end

    def exists?(type, hash)
      (directory(type, hash) &&
      directory(type, hash).files.head(key_component(type, hash))) ? true : false
    end

    def get(type, hash)
      if dir = directory(type, hash)
        dir.files.get(key_component(type, hash))
      end
    end

    def delete(type, hash)
      raise Shrouded::Errors::ReadOnlyError if readonly?
      delete!(type, hash)
    end

    private

    def default_options
      { delayed: false, readonly: false, public: false, path: nil }
    end

    def directory_component(type, hash)
      [path, type, hash[0...2]].compact.join('/')
    end

    def key_component(type, hash)
      hash[2..hash.length]
    end

    def delete!(type, hash)
      return false unless exists?(type, hash)
      get(type, hash).destroy
    end

    def directory(type, hash)
      connection.directories.get(directory_component(type, hash))
    end

    def directory!(type, hash)
      dir = directory(type, hash)
      dir ||= connection.directories.create(
        key:    directory_component(type, hash),
        public: public?
      )
      dir
    end

    def store!(type, hash, file)
      return get(type, hash) if exists?(type, hash)
      directory!(type, hash).files.create(
        key:    key_component(type, hash),
        body:   (file.kind_of?(Fog::Model) ? file.body : file),
        public: public?
      )
    end

    def path
      @path && !@path.empty? ? @path : nil
    end
  end
end
