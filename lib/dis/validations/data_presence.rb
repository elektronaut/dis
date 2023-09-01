# frozen_string_literal: true

module Dis
  module Validations
    # = Dis Data Presence Validation
    #
    class DataPresence < ActiveModel::Validator
      # Validates that a record has data, either freshly assigned or
      # persisted in the storage. Adds a `:blank` error on `:data`if not.
      def validate(record)
        return if record.data? && record.content_hash != self.class.empty_hash

        record.errors.add(:data, :blank)
      end

      class << self
        def empty_hash
          @empty_hash ||= Dis::Storage.file_digest("")
        end
      end
    end
  end
end
