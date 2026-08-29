# frozen_string_literal: true

module Dis
  class Engine < ::Rails::Engine
    config.dis = ActiveSupport::OrderedOptions.new

    initializer "dis.config" do |app|
      config.after_initialize do
        Dis.queue = app.config.dis.queue if app.config.dis.key?(:queue)
      end
    end
  end
end
