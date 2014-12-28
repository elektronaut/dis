# encoding: utf-8

module Dis
  module Jobs
    # = Dis Delete Job
    #
    # Handles delayed deletion of objects.
    #
    #   Dis::Jobs::Delete.perform_later("documents", hash)
    class Delete < ActiveJob::Base
      queue_as :dis

      def perform(type, hash)
        Dis::Storage.delayed_delete(type, hash)
      end
    end
  end
end
