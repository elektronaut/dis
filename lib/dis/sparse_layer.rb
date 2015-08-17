# encoding: utf-8

module Dis
  # = Dis SparseLayer
  #
  # A special case of Dis::Layer intended to be sparsely populated.
  # Can be configured with a size limit, objects that have been transferred
  # to other layers will be evicted based on a Least Recently Used basis.
  #
  # ==== Example
  #
  #   Dis::SparseLayer.new(
  #     Fog::Storage.new({
  #       provider: 'Local',
  #       local_root: Rails.root.join('db', 'dis')
  #     }),
  #     path: Rails.env,
  #     limit: 10.gigabytes
  #   )
  class SparseLayer < Layer
    def initialize(connection, options={})
      super
      @limit = options[:limit]
    end

    def limit?
      @limit ? true : false
    end

    def store(type, hash, file)
      super.tap do
        update_timestamp(type, hash)
      end
    end

    def get(type, hash)
      super.tap do |result|
        update_timestamp(type, hash) if result
      end
    end

    def delete(type, hash)
      super.tap do
        delete_timestamp(type, hash)
      end
    end

    private

    def delete_timestamp(type, path)
      return false unless timestamp_exists?(type, path)
      get_timestamp(type, path).destroy
    end

    def get_timestamp(type, hash)
      if dir = directory(type, hash)
        dir.files.get(timestamp_path(type, hash))
      end
    end

    def outdated_timestamp?(timestamp)
      !timestamp || timestamp < 5.minutes.ago
    end

    def read_timestamp(type, hash)
      if timestamp = get_timestamp(type, hash)
        DateTime.parse(timestamp.body)
      end
    end

    def timestamp_exists?(type, hash)
      if (directory(type, hash) &&
          directory(type, hash).files.head(timestamp_path(type, hash)))
        true
      else
        false
      end
    end

    def timestamp_path(type, hash)
      key_component(type, hash) + ".timestamp"
    end

    def update_timestamp(type, hash)
      if outdated_timestamp?(read_timestamp(type, hash))
        write_timestamp(type, hash)
      end
    end

    def write_timestamp(type, hash)
      directory!(type, hash).files.create(
        key:    timestamp_path(type, hash),
        body:   DateTime.now.to_s,
        public: public?
      )
    end
  end
end
