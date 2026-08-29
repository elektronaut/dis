# frozen_string_literal: true

require "spec_helper"

describe Dis::Jobs do
  subject(:queue_names) { job_classes.map { |k| k.new.queue_name } }

  let(:job_classes) do
    [Dis::Jobs::Store, Dis::Jobs::Delete,
     Dis::Jobs::ChangeType, Dis::Jobs::Evict]
  end

  after { Dis.queue = nil }

  describe "queue name" do
    context "when Dis.queue is not set" do
      it { is_expected.to all(eq(ActiveJob::Base.default_queue_name)) }
    end

    context "when Dis.queue is set" do
      before { Dis.queue = :dis }

      it { is_expected.to all(eq("dis")) }
    end
  end
end
