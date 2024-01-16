# frozen_string_literal: true

module Dis
  module Jobs
    # = Dis ChangeType Job
    #
    # Handles delayed object type change.
    #
    #   Dis::Jobs::ChangeType.perform_later("old_things", "new_things", key)
    class ChangeType < ActiveJob::Base
      queue_as :dis

      retry_on StandardError, attempts: 10, wait: :polynomially_longer

      def perform(prev_type, new_type, key)
        Dis::Storage.delayed_store(new_type, key)
        Dis::Storage.delayed_delete(prev_type, key)
      end
    end
  end
end
