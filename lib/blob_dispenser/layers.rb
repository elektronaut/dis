module BlobDispenser
  class Layers < Array
    def delayed
      select { |layer| layer.delayed? }
    end

    def delayed?
      delayed.any?
    end

    def immediate
      select { |layer| layer.immediate? }
    end

    def immediate?
      immediate.any?
    end
  end
end