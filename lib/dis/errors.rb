# frozen_string_literal: true

module Dis
  # Namespace for all Dis error classes.
  module Errors
    # Base error class for all Dis errors.
    class Error < StandardError; end

    # Raised when attempting to write to a readonly layer.
    class ReadOnlyError < Dis::Errors::Error; end

    # Raised when no storage layers are configured, or no writeable
    # immediate layers exist for a write operation.
    class NoLayersError < Dis::Errors::Error; end

    # Raised when a file cannot be found in any storage layer.
    class NotFoundError < Dis::Errors::Error; end

    # Raised when attempting to store a record that has no data
    # assigned.
    class NoDataError < Dis::Errors::Error; end
  end
end
