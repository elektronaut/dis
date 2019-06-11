# encoding: utf-8

module Dis
  module Jobs
    # = Dis ChangeType Job
    #
    # Handles delayed object type change.
    #
    #   Dis::Jobs::ChangeType.perform_later("old_things", "new_things", key)
    class ChangeType < ActiveJob::Base
      queue_as :dis

      def perform(prev_type, new_type, key)
        Dis::Storage.delayed_store(new_type, key)
        Dis::Storage.delayed_delete(prev_type, key)
      end
    end
  end
end
