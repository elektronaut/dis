# frozen_string_literal: true

class ImagesController < ApplicationController
  include Dis::Controller

  def show
    send_dis_data(Image.find(params.expect(:id)), disposition: "inline")
  end

  def download
    send_dis_data(Image.find(params.expect(:id)))
  end
end
