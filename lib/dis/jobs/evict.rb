# frozen_string_literal: true

module Dis
  module Jobs
    # = Dis Evict Job
    #
    # Handles cache eviction for cache layers.
    #
    #   Dis::Jobs::Evict.perform_later
    class Evict < ActiveJob::Base
      queue_as :dis

      retry_on StandardError, attempts: 10, wait: :polynomially_longer

      def perform
        Dis::Storage.evict_caches
      end
    end
  end
end
