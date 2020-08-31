# frozen_string_literal: true

module Dis
  module Jobs
    # = Dis Store Job
    #
    # Handles delayed storage of objects.
    #
    #   Dis::Jobs::Store.perform_later("documents", key)
    class Store < ActiveJob::Base
      queue_as :dis

      def perform(type, key)
        Dis::Storage.delayed_store(type, key)
      rescue Dis::Errors::NotFoundError
        Rails.logger.warn(
          "Delayed store failed, object not found: #{[type, key].inspect}"
        )
      end
    end
  end
end
