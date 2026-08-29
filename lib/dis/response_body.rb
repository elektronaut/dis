# frozen_string_literal: true

module Dis
  # = Dis Response Body
  #
  # Rack body that streams an open file and closes it once the
  # response has been sent. The file may already be unlinked, so it is
  # read through the open descriptor and never by path.
  #
  # Streams only +range+ when one is given.
  class ResponseBody
    CHUNK_SIZE = 16_384

    delegate :closed?, to: :@file

    # @return [Range, nil] the range being streamed, or nil for all of it
    attr_reader :range

    # @param file [File] an open, readable file
    # @param range [Range, nil] byte range to stream, or nil for all of it
    def initialize(file, range: nil)
      @file = file
      @range = range
    end

    # Returns the number of bytes that will be written.
    #
    # @return [Integer]
    def length
      range ? range.size : @file.size
    end

    # Returns the contents as a binary string.
    #
    # @return [String]
    def body
      seek
      @file.read(length).to_s
    end

    # Yields the contents in chunks.
    #
    # @yieldparam chunk [String] a chunk of the contents
    # @return [void]
    def each
      seek
      remaining = length
      while remaining.positive? && (chunk = @file.read([CHUNK_SIZE, remaining].min))
        remaining -= chunk.bytesize
        yield chunk
      end
    end

    # Closes the underlying file.
    #
    # @return [void]
    def close
      @file.close unless @file.closed?
    end

    private

    def seek
      @file.seek(range ? range.begin : 0)
    end
  end
end
