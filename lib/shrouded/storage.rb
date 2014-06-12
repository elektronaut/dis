# encoding: utf-8

module Shrouded
  class Storage
    class << self
      def layers
        @layers ||= Shrouded::Layers.new
      end

      def store(type, file)
        require_writeable_layers!
        hash = store_immediately!(type, file)
        if layers.delayed.writeable.any?
          Shrouded::Jobs::Store.enqueue(type, hash)
        end
        hash
      end

      def delayed_store(type, hash)
        file = get(type, hash)
        layers.delayed.writeable.each do |layer|
          layer.store(type, hash, file)
        end
      end

      def exists?(type, hash)
        require_layers!
        layers.each do |layer|
          return true if layer.exists?(type, hash)
        end
        false
      end

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