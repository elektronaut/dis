# encoding: utf-8

module Shrouded
  module Jobs
    # = Shrouded Delete Job
    #
    # Handles delayed deletion of objects.
    #
    #   Shrouded::Jobs::Delete.enqueue("documents", hash)
    class Delete < ActiveJob::Base
      queue_as :shrouded

      def perform(type, hash)
        Shrouded::Storage.delayed_delete(type, hash)
      end
    end
  end
end