# frozen_string_literal: true

require "ruby-progressbar"

namespace :dis do
  desc "List records with no backing file in any storage layer"
  task missing: :environment do
    unless ENV["MODELS"]
      puts "Usage: #{$PROGRAM_NAME} dis:missing MODELS=Avatar,Document"
      exit
    end

    models = ENV["MODELS"].split(",").map(&:strip).map(&:constantize)

    models.each do |model|
      bar = ProgressBar.create(
        title: model.name,
        total: model.where.not(
          model.dis_attributes[:content_hash] => nil
        ).count,
        format: "%t: |%B| %c/%C records"
      )

      missing = ActiveRecord::Base.logger.silence do
        Dis::Storage.missing_keys(model) do |count|
          bar.progress += count
        end
      end
      bar.finish

      if missing.any?
        puts "#{missing.length} missing:"
        missing.each { |key| puts "  #{key}" }
      else
        puts "0 missing"
      end
    end
  end

  desc "List stored files with no matching database record"
  task orphaned: :environment do
    unless ENV["MODELS"]
      puts "Usage: #{$PROGRAM_NAME} dis:orphaned MODELS=Avatar,Document"
      exit
    end

    models = ENV["MODELS"].split(",").map(&:strip).map(&:constantize)

    models.each do |model|
      orphans = ActiveRecord::Base.logger.silence do
        Dis::Storage.orphaned_keys(model)
      end
      if orphans.any?
        orphans.each do |layer, keys|
          puts "#{model.name} (#{layer.name}): " \
               "#{keys.length} orphaned"
          keys.each { |key| puts "  #{key}" }
        end
      else
        puts "#{model.name}: 0 orphaned"
      end
    end
  end
end
