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
      send_file_headers!(
        { filename: filename || dis_metadata(record, :filename),
          type: content_type || dis_metadata(record, :content_type),
          disposition: }.compact
      )
      self.status = status
      response.headers["Content-Length"] = file.size.to_s
      self.response_body = Dis::ResponseBody.new(file)
    end

    def dis_metadata(record, name)
      attribute = record.class.dis_attributes[name]
      record[attribute] if attribute
    end
  end
end
