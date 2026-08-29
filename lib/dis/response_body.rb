# frozen_string_literal: true

require "securerandom"

module Dis
  # = Dis Response Body
  #
  # Rack body that streams an open file and closes it once the
  # response has been sent. The file may already be unlinked, so it is
  # read through the open descriptor and never by path.
  #
  # Streams only the given ranges when any are given, as a
  # +multipart/byteranges+ payload if there is more than one.
  class ResponseBody
    CHUNK_SIZE = 16_384

    delegate :closed?, to: :@file

    # @return [Array<Range>] the ranges being streamed
    attr_reader :ranges

    # @return [String, nil] the multipart boundary, when multipart
    attr_reader :boundary

    # @param file [File] an open, readable file
    # @param ranges [Array<Range>, nil] byte ranges, or nil for all of it
    # @param content_type [String, nil] content type of the parts
    def initialize(file, ranges: nil, content_type: nil)
      @file = file
      @ranges = Array(ranges)
      @content_type = content_type
      @boundary = SecureRandom.hex(16) if multipart?
    end

    # @return [Boolean] whether more than one range is being streamed
    def multipart?
      ranges.length > 1
    end

    # @return [Range, nil] the range being streamed, unless multipart
    def range
      ranges.first unless multipart?
    end

    # Returns the number of bytes that will be written.
    #
    # @return [Integer]
    def length
      return @file.size if ranges.empty?
      return multipart_length if multipart?

      range.size
    end

    # Returns the contents as a binary string.
    #
    # @return [String]
    def body
      (+"").b.tap { |out| each { |chunk| out << chunk } }
    end

    # Yields the contents in chunks.
    #
    # @yieldparam chunk [String] a chunk of the contents
    # @return [void]
    def each(&)
      return stream(0, @file.size, &) if ranges.empty?
      return stream(range.begin, range.size, &) unless multipart?

      each_part(&)
    end

    # Signals that no more content will be written. This does not
    # release the file. ActionController::Live calls it as soon as the
    # body is assigned, long before Rack iterates it.
    #
    # @return [void]
    def close
      nil
    end

    # Releases the file. Rack's end-of-response close arrives here
    # through ActionDispatch::Response#abort.
    #
    # @return [void]
    def abort
      @file.close unless @file.closed?
    end

    private

    def each_part(&)
      ranges.each do |range|
        yield heading(range)
        stream(range.begin, range.size, &)
      end
      yield terminator
    end

    def stream(offset, remaining)
      @file.seek(offset)
      while remaining.positive? &&
            (chunk = @file.read([CHUNK_SIZE, remaining].min))
        remaining -= chunk.bytesize
        yield chunk
      end
    end

    def multipart_length
      ranges.sum { |range| heading(range).bytesize + range.size } +
        terminator.bytesize
    end

    def heading(range)
      "\r\n--#{boundary}\r\n" \
        "Content-Type: #{@content_type}\r\n" \
        "Content-Range: bytes #{range.begin}-#{range.end}/#{@file.size}\r\n" \
        "\r\n"
    end

    def terminator
      "\r\n--#{boundary}--\r\n"
    end
  end
end
