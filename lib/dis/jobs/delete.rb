# frozen_string_literal: true

module Dis
  module Jobs
    # = Dis Delete Job
    #
    # Handles delayed deletion of objects from all delayed layers.
    # Retries up to 10 times on failure.
    #
    # @example
    #   Dis::Jobs::Delete.perform_later("documents", key)
    class Delete < ActiveJob::Base
      queue_as :dis

      retry_on StandardError, attempts: 10, wait: :polynomially_longer

      # @param type [String] the type scope
      # @param key [String] the content hash
      # @return [void]
      def perform(type, key)
        Dis::Storage.delayed_delete(type, key)
      end
    end
  end
end
