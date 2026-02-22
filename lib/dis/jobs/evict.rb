# frozen_string_literal: true

module Dis
  module Jobs
    # = Dis Evict Job
    #
    # Handles cache eviction for cache layers. Evicts files in LRU
    # order, but only after they have been replicated to a
    # non-cache writeable layer. Retries up to 10 times on failure.
    #
    # @example
    #   Dis::Jobs::Evict.perform_later
    class Evict < ActiveJob::Base
      queue_as :dis

      retry_on StandardError, attempts: 10, wait: :polynomially_longer

      # @return [void]
      def perform
        Dis::Storage.evict_caches
      end
    end
  end
end
