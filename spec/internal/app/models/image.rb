class Image < ActiveRecord::Base
  include Shrouded::Model
  attr_accessor :accept
  validates :accept, presence: true
end
