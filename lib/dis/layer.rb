# frozen_string_literal: true

module Dis
  # = Dis Layer
  #
  # Represents a layer of storage. It's a wrapper around
  # <tt>Fog::Storage</tt>, any provider supported by Fog should be usable.
  #
  # ==== Options
  #
  # * <tt>:delayed</tt> - Delayed layers will be processed outside of
  #   the request cycle by ActiveJob.
  # * <tt>:readonly</tt> - Readonly layers can only be read from,
  #   not written to.
  # * <tt>:public</tt> - Objects stored in public layers will have the
  #   public readable flag set if supported by the storage provider.
  # * <tt>:path</tt> - Directory name to use for the store. For Amazon S3,
  #   this will be the name of the bucket.
  # * <tt>:cache</tt> - Marks the layer as a bounded cache with LRU
  #   eviction. The value specifies the soft size limit in bytes.
  #   Cannot be combined with <tt>:delayed</tt> or
  #   <tt>:readonly</tt>.
  #
  # ==== Examples
  #
  # This creates a local storage layer. It's a good idea to have a local layer
  # first, this provides you with a cache on disk that will be faster than
  # reading from the cloud.
  #
  #   Dis::Layer.new(
  #     Fog::Storage.new({
  #       provider: 'Local',
  #       local_root: Rails.root.join('db', 'dis')
  #     }),
  #     path: Rails.env
  #   )
  #
  # This creates a delayed layer on Amazon S3. ActiveJob will kick in and
  # and transfer content from one of the immediate layers later at it's
  # leisure.
  #
  #   Dis::Layer.new(
  #     Fog::Storage.new({
  #       provider:              'AWS',
  #       aws_access_key_id:     YOUR_AWS_ACCESS_KEY_ID,
  #       aws_secret_access_key: YOUR_AWS_SECRET_ACCESS_KEY
  #     }),
  #     path: "my_bucket",
  #     delayed: true
  #   )
  class Layer
    include Dis::Logging

    attr_reader :connection

    def initialize(connection, options = {})
      options     = default_options.merge(options)
      @connection = connection
      @delayed    = options[:delayed]
      @readonly   = options[:readonly]
      @public     = options[:public]
      @path       = options[:path]
      @cache      = options[:cache]
      validate_cache_options!
    end

    # Returns true if the layer is a delayed layer.
    def delayed?
      @delayed
    end

    # Returns true if the layer isn't a delayed layer.
    def immediate?
      !delayed?
    end

    # Returns true if the layer is public.
    def public?
      @public
    end

    # Returns true if the layer is read only.
    def readonly?
      @readonly
    end

    # Returns true if the layer is writeable.
    def writeable?
      !readonly?
    end

    # Returns true if the layer is a cache layer.
    def cache?
      !!@cache
    end

    # Returns the cache size limit in bytes, or nil if not a cache.
    def max_size
      @cache if cache?
    end

    # Returns the total size in bytes of all files stored locally.
    # Returns 0 for non-local providers.
    def size
      return 0 unless connection.respond_to?(:local_root)

      root = local_root_path
      return 0 unless root.exist?

      root.glob("**/*").sum { |f| f.file? ? f.size : 0 }
    end

    # Returns an array of cached file entries sorted by mtime
    # ascending (oldest first). Each entry is a hash with keys:
    # path, type, key, mtime, size.
    def cached_files
      return [] unless connection.respond_to?(:local_root)

      root = local_root_path
      return [] unless root.exist?

      entries = root.glob("**/*").select(&:file?)
      entries.filter_map { |f| cached_file_entry(f, root) }
             .sort_by { |e| e[:mtime] }
    end

    # Stores a file.
    #
    #   key = Digest::SHA1.file(file.path).hexdigest
    #   layer.store("documents", key, path)
    #
    # The key must be a hex digest of the file content. If an object with the
    # supplied hash already exists, no action will be performed. In other
    # words, no data will be overwritten if a hash collision occurs.
    #
    # Returns an instance of Fog::Model, or raises an error if the layer
    # is readonly.
    def store(type, key, file)
      raise Dis::Errors::ReadOnlyError if readonly?

      debug_log("Store #{type}/#{key} to #{name}") do
        store!(type, key, file)
      end
    end

    # Returns all the given keys that exist in the layer.
    #
    #    layer.existing("documents", keys)
    def existing(type, keys)
      return [] if keys.empty?

      futures = keys.map do |key|
        Concurrent::Promises.future { key if exists?(type, key) }
      end
      futures.filter_map(&:value!)
    end

    # Returns all content hashes stored under the given type.
    #
    #    layer.stored_keys("documents")
    def stored_keys(type)
      dir = connection.directories.get(path || "")
      return [] unless dir

      prefix = "#{type}/"
      dir.files.filter_map do |file|
        next unless file.key.start_with?(prefix)

        parts = file.key.delete_prefix(prefix).split("/")
        next unless parts.length == 2

        "#{parts[0]}#{parts[1]}"
      end
    end

    # Returns true if a object with the given key exists.
    #
    #    layer.exists?("documents", key)
    def exists?(type, key)
      if directory(type, key)&.files&.head(key_component(type, key))
        true
      else
        false
      end
    end

    # Retrieves a file from the store.
    #
    #    layer.get("documents", key)
    def get(type, key)
      dir = directory(type, key)
      return unless dir

      result = debug_log("Get #{type}/#{key} from #{name}") do
        dir.files.get(key_component(type, key))
      end
      touch_file(type, key) if result && cache?
      result
    end

    # Returns the absolute file path for a locally stored file, or nil
    # if the provider is not local or the file does not exist.
    #
    #    layer.file_path("documents", key)
    def file_path(type, key)
      return unless connection.respond_to?(:local_root)
      return unless exists?(type, key)

      File.join(
        connection.local_root,
        directory_component(type, key),
        key_component(type, key)
      )
    end

    # Deletes a file from the store.
    #
    #   layer.delete("documents", key)
    #
    # Returns true if the file was deleted, or false if it could not be found.
    # Raises an error if the layer is readonly.
    def delete(type, key)
      raise Dis::Errors::ReadOnlyError if readonly?

      debug_log("Delete #{type}/#{key} from #{name}") do
        delete!(type, key)
      end
    end

    # Returns a name for the layer.
    #
    #   layer.name # => "Fog::Storage::Local::Real/development"
    def name
      "#{connection.class.name}/#{path}"
    end

    private

    def default_options
      { delayed: false, readonly: false, public: false,
        path: nil, cache: false }
    end

    def validate_cache_options!
      return unless cache?

      if delayed?
        raise ArgumentError,
              "cache layers cannot be delayed"
      end
      return unless readonly?

      raise ArgumentError,
            "cache layers cannot be readonly"
    end

    def local_root_path
      root = Pathname.new(connection.local_root)
      path ? root.join(path) : root
    end

    def cached_file_entry(file, root)
      parts = file.relative_path_from(root).to_s.split("/")
      return unless parts.length == 3

      { path: file, type: parts[0], key: parts[1] + parts[2],
        mtime: file.mtime, size: file.size }
    end

    def touch_file(type, key)
      fp = file_path(type, key)
      FileUtils.touch(fp) if fp
    end

    def directory_component(_type, _key)
      path || ""
    end

    def key_component(type, key)
      [type, key[0...2], key[2..]].compact.join("/")
    end

    def delete!(type, key)
      return false unless exists?(type, key)

      get(type, key).destroy
    end

    def directory(type, key)
      connection.directories.get(directory_component(type, key))
    end

    def directory!(type, key)
      dir = directory(type, key)
      dir ||= connection.directories.create(
        key: directory_component(type, key),
        public: public?
      )
      dir
    end

    def store!(type, key, file)
      return get(type, key) if exists?(type, key)

      file.rewind if file.respond_to?(:rewind)
      directory!(type, key).files.create(
        key: key_component(type, key),
        body: (file.is_a?(Fog::Model) ? file.body : file),
        public: public?
      )
    end

    def path
      @path.presence
    end
  end
end
