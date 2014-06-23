# encoding: utf-8

module Shrouded
  # = Shrouded Storage
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
  # Layers should be added to <tt>Shrouded::Storage.layers</tt>. At least
  # one writeable, non-delayed layer must exist.
  class Storage
    class << self
      # Exposes the layer set, which is an instance of
      # <tt>Shrouded::Layers</tt>.
      def layers
        @layers ||= Shrouded::Layers.new
      end

      # Stores a file and returns a digest. Kicks off a
      # <tt>Shrouded::Jobs::Store</tt> job if any delayed layers are defined.
      #
      #   hash = Shrouded::Storage.store("things", File.open('foo.bin'))
      #   # => "8843d7f92416211de9ebb963ff4ce28125932878"
      def store(type, file)
        require_writeable_layers!
        hash = store_immediately!(type, file)
        if layers.delayed.writeable.any?
          Shrouded::Jobs::Store.enqueue(type, hash)
        end
        hash
      end

      # Transfers files from immediate layers to all delayed layers.
      #
      #   Shrouded::Storage.delayed_store("things", hash)
      def delayed_store(type, hash)
        file = get(type, hash)
        layers.delayed.writeable.each do |layer|
          layer.store(type, hash, file)
        end
      end

      # Returns true if the file exists in any layer.
      #
      #   Shrouded::Storage.exists?("things", hash) # => true
      def exists?(type, hash)
        require_layers!
        layers.each do |layer|
          return true if layer.exists?(type, hash)
        end
        false
      end

      # Retrieves a file from the store.
      #
      #   stuff = Shrouded::Storage.get("things", hash)
      #
      # If any misses are detected, it will try to fetch the file from the
      # first available layer, then store it in all immediate layer.
      #
      # Returns an instance of Fog::Model.
      def get(type, hash)
        require_layers!
        miss = false
        layers.each do |layer|
          if result = layer.get(type, hash)
            store_immediately!(type, result) if miss
            return result
          else
            miss = true
          end
        end
        raise Shrouded::Errors::NotFoundError
      end

      # Deletes a file from all layers. Kicks off a
      # <tt>Shrouded::Jobs::Delete</tt> job if any delayed layers are defined.
      # Returns true if the file existed in any immediate layers,
      # or false if not.
      #
      #   Shrouded::Storage.delete("things", hash)
      #   # => true
      #   Shrouded::Storage.delete("things", hash)
      #   # => false
      def delete(type, hash)
        require_writeable_layers!
        deleted = false
        layers.immediate.writeable.each do |layer|
          deleted = true if layer.delete(type, hash)
        end
        if layers.delayed.writeable.any?
          Shrouded::Jobs::Delete.enqueue(type, hash)
        end
        deleted
      end

      # Deletes content from all delayed layers.
      #
      #   Shrouded::Storage.delayed_delete("things", hash)
      def delayed_delete(type, hash)
        layers.delayed.writeable.each do |layer|
          layer.delete(type, hash)
        end
      end

      private

      def store_immediately!(type, file)
        hash_file(file) do |hash|
          layers.immediate.writeable.each do |layer|
            layer.store(type, hash, file)
          end
        end
      end

      def require_layers!
        unless layers.any?
          raise Shrouded::Errors::NoLayersError
        end
      end

      def require_writeable_layers!
        unless layers.immediate.writeable.any?
          raise Shrouded::Errors::NoLayersError
        end
      end

      def digest
        Digest::SHA1
      end

      def hash_file(file, &block)
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
    end
  end
end