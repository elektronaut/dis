class Image < ActiveRecord::Base
  shrouded_model
  attr_accessor :accept
  validates :accept, presence: true
end
