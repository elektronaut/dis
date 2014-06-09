module Shrouded
  module Jobs
    class Store < ActiveJob::Base
      queue_as :shrouded

      def perform(hash)
        Shrouded::Storage.delayed_store(hash)
      end
    end
  end
end