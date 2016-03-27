# encoding: utf-8

module Dis
  module Validations
    # = Dis Data Presence Validation
    #
    class DataPresence < ActiveModel::Validator
      # Validates that a record has data, either freshly assigned or
      # persisted in the storage. Adds a `:blank` error on `:data`if not.
      def validate(record)
        record.errors.add(:data, :blank) unless record.data?
      end
    end
  end
end
