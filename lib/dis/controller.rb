# frozen_string_literal: true

module Dis
  # = Dis Controller
  #
  # Adds {#send_dis_data} for serving stored data from a controller.
  #
  #   class DocumentsController < ApplicationController
  #     include Dis::Controller
  #
  #     def show
  #       send_dis_data(Document.find(params[:id]))
  #     end
  #   end
  module Controller
    extend ActiveSupport::Concern

    included do
      include ActionController::DataStreaming
    end

    private

    # Sends the record's data to the client. Works like +send_file+,
    # but reads through an open descriptor rather than a path, so the
    # response is unaffected if the content is evicted or deleted
    # while it is being written.
    #
    # +filename+ and +content_type+ default to the record's own
    # metadata.
    #
    # Responds with +206 Partial Content+ to a range request, or +416
    # Range Not Satisfiable+ if the range lies beyond the data. Several
    # ranges are sent as +multipart/byteranges+.
    #
    # @param record [Dis::Model] the record to send data from
    # @param filename [String, nil] suggested filename
    # @param content_type [String, nil] the content type
    # @param disposition [String] +"attachment"+ or +"inline"+
    # @param status [Integer] the HTTP status code
    # @return [void]
    # @raise [Dis::Errors::NotFoundError] if the data is not found
    #
    # @example
    #   send_dis_data(document, disposition: "inline")
    def send_dis_data(record, filename: nil, content_type: nil,
                      disposition: "attachment", status: 200)
      file = record.open_data
      ranges = dis_byte_ranges(file.size, status)
      response.headers["Accept-Ranges"] = "bytes"
      return dis_unsatisfiable_range(file) if ranges && ranges.empty?

      type = content_type || dis_metadata(record, :content_type)
      dis_send_file_headers(record, filename, type, disposition)
      dis_send_body(
        Dis::ResponseBody.new(file, ranges:, content_type: type), file.size,
        status
      )
    end

    def dis_byte_ranges(size, status)
      return unless status == 200
      return unless dis_if_range_matches?

      Rack::Utils.get_byte_ranges(request.get_header("HTTP_RANGE"), size)
    end

    def dis_if_range_matches?
      if_range = request.get_header("HTTP_IF_RANGE")
      return true if if_range.blank?

      [response.etag, response.headers["Last-Modified"]].any? do |validator|
        validator.present? && if_range == validator
      end
    end

    def dis_unsatisfiable_range(file)
      response.headers["Content-Range"] = "bytes */#{file.size}"
      file.close
      head :range_not_satisfiable
    end

    def dis_send_file_headers(record, filename, type, disposition)
      send_file_headers!(
        { filename: filename || dis_metadata(record, :filename),
          type:, disposition: }.compact
      )
    end

    def dis_send_body(body, size, status)
      self.status = body.ranges.any? ? :partial_content : status
      dis_partial_headers(body, size)
      response.headers["Content-Length"] = body.length.to_s
      self.response_body = body
    end

    def dis_partial_headers(body, size)
      if body.multipart?
        self.content_type =
          "multipart/byteranges; boundary=#{body.boundary}"
      elsif body.range
        response.headers["Content-Range"] =
          "bytes #{body.range.begin}-#{body.range.end}/#{size}"
      end
    end

    def dis_metadata(record, name)
      attribute = record.class.dis_attributes[name]
      record[attribute] if attribute
    end
  end
end
