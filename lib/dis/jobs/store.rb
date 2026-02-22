# frozen_string_literal: true

module Dis
  module Jobs
    # = Dis Store Job
    #
    # Handles delayed storage of objects. Replicates content from
    # immediate layers to all delayed layers. Retries up to 10
    # times on failure. Discarded if the source file no longer
    # exists.
    #
    # @example
    #   Dis::Jobs::Store.perform_later("documents", key)
    class Store < ActiveJob::Base
      queue_as :dis

      discard_on Dis::Errors::NotFoundError

      retry_on StandardError, attempts: 10, wait: :polynomially_longer

      # @param type [String] the type scope
      # @param key [String] the content hash
      # @return [void]
      def perform(type, key)
        Dis::Storage.delayed_store(type, key)
      end
    end
  end
end
