# encoding: utf-8

module Dis
  # = Dis Storage
  #
  # This is the interface for interacting with the storage layers.
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
      # Returns a hex digest for a given binary. Accepts files, strings
      # and Fog models.
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

      # Exposes the layer set, which is an instance of
      # <tt>Dis::Layers</tt>.
      def layers
        @layers ||= Dis::Layers.new
      end

      # Changes the type of an object. Kicks off a
      # <tt>Dis::Jobs::ChangeType</tt> job if any delayed layers are defined.
      #
      #   Dis::Storage.change_type("old_things", "new_things", key)
      def change_type(prev_type, new_type, key)
        require_writeable_layers!
        file = get(prev_type, key)
        store_immediately!(new_type, file)
        layers.immediate.writeable.each do |layer|
          layer.delete(prev_type, key)
        end
        if layers.delayed.writeable.any?
          Dis::Jobs::ChangeType.perform_later(prev_type, new_type, key)
        end
        key
      end

      # Stores a file and returns a digest. Kicks off a
      # <tt>Dis::Jobs::Store</tt> job if any delayed layers are defined.
      #
      #   hash = Dis::Storage.store("things", File.open('foo.bin'))
      #   # => "8843d7f92416211de9ebb963ff4ce28125932878"
      def store(type, file)
        require_writeable_layers!
        hash = store_immediately!(type, file)
        if layers.delayed.writeable.any?
          Dis::Jobs::Store.perform_later(type, hash)
        end
        hash
      end

      # Transfers files from immediate layers to all delayed layers.
      #
      #   Dis::Storage.delayed_store("things", hash)
      def delayed_store(type, hash)
        file = get(type, hash)
        layers.delayed.writeable.each do |layer|
          layer.store(type, hash, file)
        end
      end

      # Returns true if the file exists in any layer.
      #
      #   Dis::Storage.exists?("things", key) # => true
      def exists?(type, key)
        require_layers!
        layers.each do |layer|
          return true if layer.exists?(type, key)
        end
        false
      end

      # Retrieves a file from the store.
      #
      #   stuff = Dis::Storage.get("things", hash)
      #
      # If any misses are detected, it will try to fetch the file from the
      # first available layer, then store it in all immediate layer.
      #
      # Returns an instance of Fog::Model.
      def get(type, key)
        require_layers!

        fetch_count = 0
        result = layers.inject(nil) do |res, layer|
          res || lambda do
            fetch_count += 1
            layer.get(type, key)
          end.call
        end

        raise Dis::Errors::NotFoundError unless result

        store_immediately!(type, result) if fetch_count > 1
        result
      end

      # Deletes a file from all layers. Kicks off a
      # <tt>Dis::Jobs::Delete</tt> job if any delayed layers are defined.
      # Returns true if the file existed in any immediate layers,
      # or false if not.
      #
      #   Dis::Storage.delete("things", key)
      #   # => true
      #   Dis::Storage.delete("things", key)
      #   # => false
      def delete(type, key)
        require_writeable_layers!
        deleted = false
        layers.immediate.writeable.each do |layer|
          deleted = true if layer.delete(type, key)
        end
        if layers.delayed.writeable.any?
          Dis::Jobs::Delete.perform_later(type, key)
        end
        deleted
      end

      # Deletes content from all delayed layers.
      #
      #   Dis::Storage.delayed_delete("things", hash)
      def delayed_delete(type, key)
        layers.delayed.writeable.each do |layer|
          layer.delete(type, key)
        end
      end

      private

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

      def digest
        Digest::SHA1
      end
    end
  end
end
