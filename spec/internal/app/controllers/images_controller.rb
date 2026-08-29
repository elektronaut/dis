# frozen_string_literal: true

class ImagesController < ApplicationController
  include Dis::Controller

  def show
    send_dis_data(Image.find(params.expect(:id)), disposition: "inline")
  end

  def download
    send_dis_data(Image.find(params.expect(:id)))
  end

  def cached
    image = Image.find(params.expect(:id))
    response.strong_etag = image.content_hash
    send_dis_data(image, disposition: "inline")
  end
end
