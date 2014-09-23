# encoding: utf-8

module Dis
  module Jobs
    # = Dis Store Job
    #
    # Handles delayed storage of objects.
    #
    #   Dis::Jobs::Store.enqueue("documents", hash)
    class Store < ActiveJob::Base
      queue_as :dis

      def perform(type, hash)
        Dis::Storage.delayed_store(type, hash)
      end
    end
  end
end