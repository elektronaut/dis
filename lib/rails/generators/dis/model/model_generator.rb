# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/model/model_generator"

module Dis
  module Generators
    class ModelGenerator < Rails::Generators::ModelGenerator
      desc "Creates a Dis model"

      def initialize(args, *options)
        super(inject_dis_attributes(args), *options)
      end

      def add_model_extension
        inject_into_file(
          File.join("app/models", class_path, "#{file_name}.rb"),
          after: "ActiveRecord::Base\n"
        ) do
          "  include Dis::Model\n"
        end
      end

      private

      def inject_dis_attributes(args)
        if args.any?
          [args[0]] + dis_attributes + args[1..args.length]
        else
          args
        end
      end

      def dis_attributes
        %w[
          content_hash:string
          content_type:string
          content_length:integer
          filename:string
        ]
      end
    end
  end
end
