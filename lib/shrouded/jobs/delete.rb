module Shrouded
  module Jobs
    class Delete < ActiveJob::Base
      queue_as :shrouded

      def perform(type, hash)
        Shrouded::Storage.delayed_delete(type, hash)
      end
    end
  end
end