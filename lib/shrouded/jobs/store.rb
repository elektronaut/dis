# encoding: utf-8

module Shrouded
  module Jobs
    # = Shrouded Store Job
    #
    # Handles delayed storage of objects.
    #
    #   Shrouded::Jobs::Store.enqueue("documents", hash)
    class Store < ActiveJob::Base
      queue_as :shrouded

      def perform(type, hash)
        Shrouded::Storage.delayed_store(type, hash)
      end
    end
  end
end