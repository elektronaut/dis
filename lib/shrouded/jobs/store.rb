module Shrouded
  module Jobs
    class Store < ActiveJob::Base
      queue_as :shrouded

      def perform(type, hash)
        Shrouded::Storage.delayed_store(type, hash)
      end
    end
  end
end