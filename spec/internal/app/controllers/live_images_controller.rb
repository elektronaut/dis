# frozen_string_literal: true

class LiveImagesController < ApplicationController
  include Dis::Controller
  include ActionController::Live

  def live
    send_dis_data(Image.find(params.expect(:id)), disposition: "inline")
  end
end
