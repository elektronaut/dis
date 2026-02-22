# frozen_string_literal: true

module Dis
  module Jobs
    # = Dis ChangeType Job
    #
    # Handles delayed object type change. Stores the content under
    # the new type in delayed layers, then deletes it under the
    # old type. Retries up to 10 times on failure.
    #
    # @example
    #   Dis::Jobs::ChangeType.perform_later("old", "new", key)
    class ChangeType < ActiveJob::Base
      queue_as :dis

      retry_on StandardError, attempts: 10, wait: :polynomially_longer

      # @param prev_type [String] the current type scope
      # @param new_type [String] the new type scope
      # @param key [String] the content hash
      # @return [void]
      def perform(prev_type, new_type, key)
        Dis::Storage.delayed_store(new_type, key)
        Dis::Storage.delayed_delete(prev_type, key)
      end
    end
  end
end
