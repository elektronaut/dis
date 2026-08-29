# frozen_string_literal: true

module Dis
  # = Dis Response Body
  #
  # Rack body that streams an open file and closes it once the
  # response has been sent. The file may already be unlinked, so it is
  # read through the open descriptor and never by path.
  class ResponseBody
    CHUNK_SIZE = 16_384

    delegate :closed?, to: :@file

    # @param file [File] an open, readable file
    def initialize(file)
      @file = file
    end

    # Returns the entire contents as a binary string.
    #
    # @return [String]
    def body
      @file.rewind
      @file.read
    end

    # Yields the contents in chunks.
    #
    # @yieldparam chunk [String] a chunk of the contents
    # @return [void]
    def each
      @file.rewind
      while (chunk = @file.read(CHUNK_SIZE))
        yield chunk
      end
    end

    # Closes the underlying file.
    #
    # @return [void]
    def close
      @file.close unless @file.closed?
    end
  end
end
