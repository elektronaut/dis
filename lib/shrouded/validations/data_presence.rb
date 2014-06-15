# encoding: utf-8

module Shrouded
  module Validations
    class DataPresence < ActiveModel::Validator
      def validate(record)
        unless record.data?
          record.errors.add(:data, :blank)
        end
      end
    end
  end
end