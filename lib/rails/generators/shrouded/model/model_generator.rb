# encoding: utf-8

require 'rails/generators'
require 'rails/generators/rails/model/model_generator'

module Shrouded
  module Generators
    class ModelGenerator < Rails::Generators::ModelGenerator

      def initialize(args, *options)
        super(inject_shrouded_attributes(args), *options)
      end

      def add_model_extension
        inject_into_file File.join('app/models', class_path, "#{file_name}.rb"), after: "ActiveRecord::Base\n" do
          "  include Shrouded::Model\n"
        end
      end

      private

      def inject_shrouded_attributes(args)
        if args.any?
          args = [args[0]] + shrouded_attributes + args[1..args.length]
        else
          args
        end
      end

      def shrouded_attributes
        %w{
          content_hash:string
          content_type:string
          content_length:integer
          filename:string
        }
      end
    end
  end
end