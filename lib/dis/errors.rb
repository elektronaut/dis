# frozen_string_literal: true

module Dis
  module Errors
    class Error < StandardError; end

    class ReadOnlyError < Dis::Errors::Error; end

    class NoLayersError < Dis::Errors::Error; end

    class NotFoundError < Dis::Errors::Error; end

    class NoDataError < Dis::Errors::Error; end
  end
end
