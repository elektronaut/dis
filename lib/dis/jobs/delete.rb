# frozen_string_literal: true

module Dis
  module Jobs
    # = Dis Delete Job
    #
    # Handles delayed deletion of objects.
    #
    #   Dis::Jobs::Delete.perform_later("documents", key)
    class Delete < ActiveJob::Base
      queue_as :dis

      def perform(type, key)
        Dis::Storage.delayed_delete(type, key)
      end
    end
  end
end
