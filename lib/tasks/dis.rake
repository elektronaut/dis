# encoding: utf-8

namespace :dis do
  desc "Check stuff"
  task consistency_check: :environment do
    unless ENV["MODELS"]
      puts "Usage: #{$PROGRAM_NAME} dis:consistency_check " \
           "MODELS=Avatar,Document"
      exit
    end

    models = ENV["MODELS"].split(",").map(&:strip).map(&:constantize)

    models.each do |model|
      puts "-- #{model.name} --"

      content_hash_attr = model.dis_attributes[:content_hash]
      objects = model
        .select(content_hash_attr)
        .uniq
        .map { |r| r.send(content_hash_attr) }

      puts "Unique objects: #{objects.length}"

      Dis::Storage.layers.each do |layer|
        existing = objects
          .pmap { |hash| [hash, layer.exists?(model.dis_type, hash)] }
          .select(&:last)
          .map(&:first)
        missing = objects - existing
        puts "#{layer.name}: #{existing.length} (#{missing.length} missing)"

        puts "Missing objects:\n#{missing.inspect}" if missing.any?
      end

      puts
    end
  end
end
