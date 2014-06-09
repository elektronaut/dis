module Shrouded
  module Jobs
    class Delete < ActiveJob::Base
      queue_as :shrouded

      def perform(hash)
        Shrouded::Storage.delayed_delete(hash)
      end
    end
  end
end