# encoding: utf-8

class Image < ActiveRecord::Base
  include Dis::Model
  attr_accessor :accept
  validates :accept, presence: true
end
