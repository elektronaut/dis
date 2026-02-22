# frozen_string_literal: true

module Dis
  # = Dis Storage
  #
  # Interface for interacting with the storage layers.
  #
  # All queries are scoped by object type, which will default to the table
  # name of the model. Take care to use your own scope if you interact with
  # the store directly, as models will purge expired content when they change.
  #
  # Files are stored with a SHA1 digest of the file contents as the key.
  # This ensures data is deduplicated per scope. Hash collisions will be
  # silently ignored.
  #
  # Layers should be added to <tt>Dis::Storage.layers</tt>. At least
  # one writeable, non-delayed layer must exist.
  class Storage
    class << self
      # Returns a hex digest for a given binary. Accepts File/IO objects,
      # strings, and Fog models.
      #
      # @param file [File, IO, String, Fog::Model] the content to digest
      # @yield [hash] if a block is given, yields the hex digest
      # @yieldparam hash [String] the computed SHA1 hex digest
      # @return [String] the SHA1 hex digest
      def file_digest(file)
        hash = case file
               when Fog::Model
                 digest.hexdigest(file.body)
               when String
                 digest.hexdigest(file)
               else
                 digest.file(file.path).hexdigest
               end
        yield hash if block_given?
        hash
      end

      # Exposes the layer set.
      #
      # @return [Dis::Layers]
      def layers
        @layers ||= Dis::Layers.new
      end

      # Changes the type of an object. Kicks off a
      # {Dis::Jobs::ChangeType} job if any delayed layers are defined.
      #
      # @param prev_type [String] the current type scope
      # @param new_type [String] the new type scope
      # @param key [String] the content hash
      # @return [String] the content hash
      # @raise [Dis::Errors::NoLayersError] if no writeable immediate
      #   layers exist
      # @raise [Dis::Errors::NotFoundError] if the file is not found
      #
      # @example
      #   Dis::Storage.change_type("old_things", "new_things", key)
      def change_type(prev_type, new_type, key)
        require_writeable_layers!
        file = get(prev_type, key)
        store_immediately!(new_type, file)
        layers.immediate.writeable.each do |layer|
          layer.delete(prev_type, key)
        end
        enqueue_delayed_jobs(prev_type, new_type, key)
        key
      end

      # Stores a file and returns a content hash. Kicks off a
      # {Dis::Jobs::Store} job if any delayed layers are defined.
      #
      # @param type [String] the type scope (e.g. table name)
      # @param file [File, IO, String, Fog::Model] the content to store
      # @return [String] the SHA1 content hash
      # @raise [Dis::Errors::NoLayersError] if no writeable immediate
      #   layers exist
      #
      # @example
      #   hash = Dis::Storage.store("things", File.open("foo.bin"))
      #   # => "8843d7f92416211de9ebb963ff4ce28125932878"
      def store(type, file)
        require_writeable_layers!
        hash = store_immediately!(type, file)
        Dis::Jobs::Store.perform_later(type, hash) if layers.delayed.writeable.any?
        Dis::Jobs::Evict.perform_later if layers.cache?
        hash
      end

      # Transfers files from immediate layers to all delayed layers.
      # Called internally by {Dis::Jobs::Store}.
      #
      # @param type [String] the type scope
      # @param hash [String] the content hash
      # @return [void]
      # @raise [Dis::Errors::NotFoundError] if the file is not found
      def delayed_store(type, hash)
        file = get(type, hash)
        layers.delayed.writeable.each do |layer|
          layer.store(type, hash, file)
        end
      end

      # Returns true if the file exists in any layer.
      #
      # @param type [String] the type scope
      # @param key [String] the content hash
      # @return [Boolean]
      # @raise [Dis::Errors::NoLayersError] if no layers are configured
      #
      # @example
      #   Dis::Storage.exists?("things", key) # => true
      def exists?(type, key)
        require_layers!
        layers.each do |layer|
          return true if layer.exists?(type, key)
        rescue StandardError => e
          report_layer_error(e, layer:, type:, key:)
        end
        false
      end

      # Retrieves a file from the store. If the first layer misses,
      # the file is fetched from the next available layer and
      # backfilled to all immediate layers.
      #
      # @param type [String] the type scope
      # @param key [String] the content hash
      # @return [Fog::Model] the stored file
      # @raise [Dis::Errors::NoLayersError] if no layers are configured
      # @raise [Dis::Errors::NotFoundError] if the file is not found
      #   in any layer
      #
      # @example
      #   file = Dis::Storage.get("things", hash)
      #   file.body # => "file contents..."
      def get(type, key)
        require_layers!
        fetch_count = 0
        result = layers.inject(nil) do |res, layer|
          next res if res

          fetch_count += 1
          fetch_from_layer(layer, type, key)
        end || raise(Dis::Errors::NotFoundError)
        backfill!(type, result) if fetch_count > 1
        result
      end

      # Returns the absolute file path from the first layer that has a
      # local copy, or nil if no layer stores files locally.
      #
      # @param type [String] the type scope
      # @param key [String] the content hash
      # @return [String, nil] the absolute file path, or nil
      # @raise [Dis::Errors::NoLayersError] if no layers are configured
      def file_path(type, key)
        require_layers!
        layers.each do |layer|
          path = layer.file_path(type, key)
          return path if path
        rescue StandardError => e
          report_layer_error(e, layer:, type:, key:)
        end
        nil
      end

      # Deletes a file from all layers. Kicks off a
      # {Dis::Jobs::Delete} job if any delayed layers are defined.
      #
      # @param type [String] the type scope
      # @param key [String] the content hash
      # @return [Boolean] true if the file existed in any immediate
      #   layer
      # @raise [Dis::Errors::NoLayersError] if no writeable immediate
      #   layers exist
      #
      # @example
      #   Dis::Storage.delete("things", key) # => true
      #   Dis::Storage.delete("things", key) # => false
      def delete(type, key)
        require_writeable_layers!
        deleted = false
        layers.immediate.writeable.each do |layer|
          deleted = true if layer.delete(type, key)
        end
        Dis::Jobs::Delete.perform_later(type, key) if layers.delayed.writeable.any?
        deleted
      end

      # Evicts cached files from all cache layers that exceed
      # their size limit. Only evicts files that have been
      # replicated to a non-cache writeable layer.
      #
      # @return [void]
      def evict_caches
        layers.cache.each { |layer| evict_cache(layer) }
      end

      # Returns content hashes from the model's table that exist in
      # no non-cache layer.
      #
      # @param model [Class] an ActiveRecord model that includes
      #   {Dis::Model}
      # @yield [batch_size] called after each batch is checked
      # @yieldparam batch_size [Integer] the number of keys in the
      #   batch
      # @return [Array<String>] content hashes with no backing file
      #
      # @example
      #   Dis::Storage.missing_keys(Image)
      def missing_keys(model)
        attr = model.dis_attributes[:content_hash]
        missing = []

        model.where.not(attr => nil).in_batches(of: 200) do |batch|
          keys = batch.pluck(attr)
          missing.concat(uncovered_keys(keys.uniq, model.dis_type))
          yield keys.size if block_given?
        end
        missing.uniq
      end

      # Returns a hash of layer => orphaned content hashes for files
      # that exist in storage but have no matching database record.
      #
      # @param model [Class] an ActiveRecord model that includes
      #   {Dis::Model}
      # @return [Hash{Dis::Layer => Array<String>}] orphaned content
      #   hashes per layer
      #
      # @example
      #   Dis::Storage.orphaned_keys(Image)
      def orphaned_keys(model)
        layers.non_cache.each_with_object({}) do |layer, result|
          orphans = layer_orphans(layer, model.dis_type, model,
                                  model.dis_attributes[:content_hash])
          result[layer] = orphans if orphans.any?
        end
      end

      # Deletes content from all delayed layers.
      # Called internally by {Dis::Jobs::Delete}.
      #
      # @param type [String] the type scope
      # @param key [String] the content hash
      # @return [void]
      def delayed_delete(type, key)
        layers.delayed.writeable.each do |layer|
          layer.delete(type, key)
        end
      end

      private

      def enqueue_delayed_jobs(prev_type, new_type, key)
        if layers.delayed.writeable.any?
          Dis::Jobs::ChangeType.perform_later(
            prev_type, new_type, key
          )
        end
        Dis::Jobs::Evict.perform_later if layers.cache?
      end

      def uncovered_keys(keys, type)
        remaining = keys.dup
        layers.non_cache.each do |layer|
          break if remaining.empty?

          remaining -= layer.existing(type, remaining)
        end
        remaining
      end

      def layer_orphans(layer, type, model, attr)
        stored = layer.stored_keys(type)
        return [] if stored.empty?

        referenced = model.where(attr => stored).pluck(attr)
        stored - referenced
      end

      def evict_cache(layer)
        return if layer.size <= layer.max_size

        current_size = layer.size
        layer.cached_files.each do |entry|
          break if current_size <= layer.max_size

          next unless replicated?(entry[:type], entry[:key])

          layer.delete(entry[:type], entry[:key])
          current_size -= entry[:size]
        end
      end

      def replicated?(type, key)
        layers.non_cache.writeable.any? do |l|
          l.exists?(type, key)
        rescue StandardError => e
          report_layer_error(e, layer: l, type:, key:)
          false
        end
      end

      def fetch_from_layer(layer, type, key)
        layer.get(type, key)
      rescue StandardError => e
        report_layer_error(e, layer:, type:, key:)
        nil
      end

      def backfill!(type, file)
        store_immediately!(type, file)
      rescue StandardError => e
        report_layer_error(e, type:)
      end

      def store_immediately!(type, file)
        file_digest(file) do |hash|
          layers.immediate.writeable.each do |layer|
            layer.store(type, hash, file)
          end
        end
      end

      def require_layers!
        raise Dis::Errors::NoLayersError unless layers.any?
      end

      def require_writeable_layers!
        raise Dis::Errors::NoLayersError unless layers.immediate.writeable.any?
      end

      def report_layer_error(err, layer: nil, type: nil, key: nil)
        Rails.error.report(
          err, handled: true,
               severity: :warning,
               context: { layer: layer&.name, type:, key: }
        )
      end

      def digest
        Digest::SHA1
      end
    end
  end
end
