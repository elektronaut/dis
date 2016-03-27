# encoding: utf-8

require 'rails/generators'
require 'rails/generators/rails/model/model_generator'

module Dis
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates the Dis initializer'
      source_root File.expand_path('../templates', __FILE__)

      def create_initializer
        template 'initializer.rb', File.join('config', 'initializers', 'dis.rb')
      end
    end
  end
end
