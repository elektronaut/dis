# encoding: utf-8

class CreateImages < ActiveRecord::Migration[5.2]
  def change
    create_table :images do |t|
      t.string  :content_hash
      t.string  :content_type
      t.integer :content_length
      t.string  :filename
    end
  end
end
