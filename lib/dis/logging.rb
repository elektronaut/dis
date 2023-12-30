# frozen_string_literal: true

module Dis
  module Logging
    def debug_log(message, &block)
      result = nil
      duration = Benchmark.ms { result = block.call }
      logger.debug(format("[Dis] %<message>s (%<duration>.1fms)",
                          message:,
                          duration:))
      result
    end

    def logger
      Rails.logger
    end
  end
end
