# encoding: utf-8

require 'rails/generators'
require 'rails/generators/rails/model/model_generator'

module Shrouded
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Creates the Shrouded initializer"
      source_root File.expand_path("../templates", __FILE__)

      def create_initializer
        template 'initializer.rb', File.join('config', 'initializers', 'shrouded.rb')
      end
    end
  end
end