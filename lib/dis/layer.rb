# frozen_string_literal: true

module Dis
  # = Dis Layer
  #
  # Represents a layer of storage. Wraps a +Fog::Storage+ connection;
  # any provider supported by Fog should be usable.
  #
  # @example Local storage layer
  #   Dis::Layer.new(
  #     Fog::Storage.new(
  #       provider: "Local",
  #       local_root: Rails.root.join("db/dis")
  #     ),
  #     path: Rails.env
  #   )
  #
  # @example Delayed layer on Amazon S3
  #   Dis::Layer.new(
  #     Fog::Storage.new(
  #       provider: "AWS",
  #       aws_access_key_id: YOUR_AWS_ACCESS_KEY_ID,
  #       aws_secret_access_key: YOUR_AWS_SECRET_ACCESS_KEY
  #     ),
  #     path: "my_bucket",
  #     delayed: true
  #   )
  class Layer
    include Dis::Logging

    # @return [Fog::Storage] the underlying Fog connection
    attr_reader :connection

    # @param connection [Fog::Storage] a Fog storage connection
    # @param options [Hash] layer configuration options
    # @option options [Boolean] :delayed (false) process writes
    #   asynchronously via ActiveJob
    # @option options [Boolean] :readonly (false) only allow reads
    # @option options [Boolean] :public (false) set the public
    #   readable flag on stored objects (provider-dependent)
    # @option options [String] :path (nil) directory or bucket name
    # @option options [Integer, false] :cache (false) enable bounded
    #   cache with this soft size limit in bytes. Cannot be combined
    #   with +:delayed+ or +:readonly+
    # @raise [ArgumentError] if +:cache+ is combined with +:delayed+
    #   or +:readonly+
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
    #
    # @return [Boolean]
    def delayed?
      @delayed
    end

    # Returns true if the layer isn't a delayed layer.
    #
    # @return [Boolean]
    def immediate?
      !delayed?
    end

    # Returns true if the layer is public.
    #
    # @return [Boolean]
    def public?
      @public
    end

    # Returns true if the layer is read only.
    #
    # @return [Boolean]
    def readonly?
      @readonly
    end

    # Returns true if the layer is writeable.
    #
    # @return [Boolean]
    def writeable?
      !readonly?
    end

    # Returns true if the layer is a cache layer.
    #
    # @return [Boolean]
    def cache?
      !!@cache
    end

    # Returns the cache size limit in bytes, or nil if not a cache.
    #
    # @return [Integer, nil]
    def max_size
      @cache if cache?
    end

    # Returns the total size in bytes of all files stored locally.
    # Returns 0 for non-local providers.
    #
    # @return [Integer]
    def size
      return 0 unless connection.respond_to?(:local_root)

      root = local_root_path
      return 0 unless root.exist?

      root.glob("**/*").sum { |f| f.file? ? f.size : 0 }
    end

    # Returns cached file entries sorted by mtime ascending
    # (oldest first).
    #
    # @return [Array<Hash>] each entry has keys +:path+
    #   (Pathname), +:type+ (String), +:key+ (String), +:mtime+
    #   (Time), +:size+ (Integer)
    def cached_files
      return [] unless connection.respond_to?(:local_root)

      root = local_root_path
      return [] unless root.exist?

      entries = root.glob("**/*").select(&:file?)
      entries.filter_map { |f| cached_file_entry(f, root) }
             .sort_by { |e| e[:mtime] }
    end

    # Stores a file. The key must be a hex digest of the file
    # content. If an object with the supplied hash already exists,
    # no action will be performed.
    #
    # @param type [String] the type scope
    # @param key [String] the content hash
    # @param file [File, IO, String, Fog::Model] the content
    # @return [Fog::Model] the stored file
    # @raise [Dis::Errors::ReadOnlyError] if the layer is readonly
    #
    # @example
    #   key = Digest::SHA1.file(file.path).hexdigest
    #   layer.store("documents", key, file)
    def store(type, key, file)
      raise Dis::Errors::ReadOnlyError if readonly?

      debug_log("Store #{type}/#{key} to #{name}") do
        store!(type, key, file)
      end
    end

    # Returns all the given keys that exist in the layer.
    #
    # @param type [String] the type scope
    # @param keys [Array<String>] content hashes to check
    # @return [Array<String>] the subset of keys that exist
    def existing(type, keys)
      return [] if keys.empty?

      futures = keys.map do |key|
        Concurrent::Promises.future { key if exists?(type, key) }
      end
      futures.filter_map(&:value!)
    end

    # Returns all content hashes stored under the given type.
    #
    # @param type [String] the type scope
    # @return [Array<String>] content hashes
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

    # Returns true if an object with the given key exists.
    #
    # @param type [String] the type scope
    # @param key [String] the content hash
    # @return [Boolean]
    def exists?(type, key)
      if directory(type, key)&.files&.head(key_component(type, key))
        true
      else
        false
      end
    end

    # Retrieves a file from the store.
    #
    # @param type [String] the type scope
    # @param key [String] the content hash
    # @return [Fog::Model, nil] the file, or nil if not found
    def get(type, key)
      dir = directory(type, key)
      return unless dir

      result = debug_log("Get #{type}/#{key} from #{name}") do
        dir.files.get(key_component(type, key))
      end
      touch_file(type, key) if result && cache?
      result
    end

    # Returns the absolute file path for a locally stored file, or
    # nil if the provider is not local or the file does not exist.
    #
    # @param type [String] the type scope
    # @param key [String] the content hash
    # @return [String, nil]
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
    # @param type [String] the type scope
    # @param key [String] the content hash
    # @return [Boolean] true if the file was deleted, false if not
    #   found
    # @raise [Dis::Errors::ReadOnlyError] if the layer is readonly
    def delete(type, key)
      raise Dis::Errors::ReadOnlyError if readonly?

      debug_log("Delete #{type}/#{key} from #{name}") do
        delete!(type, key)
      end
    end

    # Returns a name for the layer.
    #
    # @return [String]
    #
    # @example
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
