# frozen_string_literal: true

module Dis
  module Logging
    def debug_log(message, &block)
      result = nil
      duration = ::Benchmark.realtime { result = block.call } * 1000
      logger.debug(format("[Dis] %<message>s (%<duration>.1fms)",
                          message:,
                          duration:))
      result
    end

    delegate :logger, to: :Rails
  end
end
