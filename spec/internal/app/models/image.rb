# frozen_string_literal: true

class Image < ApplicationRecord
  include Dis::Model
  attr_accessor :accept

  validates :accept, presence: true
end
