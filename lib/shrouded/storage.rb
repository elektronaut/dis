module Shrouded
  class Storage
    class << self
      def layers
        @layers ||= Shrouded::Layers.new
      end

      def store(file)
        require_writeable_layers!
        store_immediately!(file)
      end

      def exists?(hash)
        require_layers!
        layers.each do |layer|
          return true if layer.exists?(hash)
        end
        false
      end

      def get(hash)
        require_layers!
        miss = false
        layers.each do |layer|
          if result = layer.get(hash)
            store_immediately!(result) if miss
            return result
          else
            miss = true
          end
        end
        raise Shrouded::Errors::NotFoundError
      end

      def delete(hash)
        require_writeable_layers!
        deleted = false
        layers.immediate.writeable.each do |layer|
          deleted = true if layer.delete(hash)
        end
        deleted
      end

      private

      def store_immediately!(file)
        hash_file(file) do |hash|
          layers.immediate.writeable.each do |layer|
            layer.store(hash, file)
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