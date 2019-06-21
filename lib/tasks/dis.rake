# frozen_string_literal: true

namespace :dis do
  desc "Check stuff"
  task consistency_check: :environment do
    unless ENV["MODELS"]
      puts "Usage: #{$PROGRAM_NAME} dis:consistency_check " \
           "MODELS=Avatar,Document"
      exit
    end

    models = ENV["MODELS"].split(",").map(&:strip).map(&:constantize)

    jobs = Set.new

    models.each do |model|
      puts "-- #{model.name} --"

      content_hash_attr = model.dis_attributes[:content_hash]
      objects = model
                .select(content_hash_attr)
                .uniq
                .map { |r| r.send(content_hash_attr) }
      global_missing = objects.dup

      puts "Unique objects: #{objects.length}"

      Dis::Storage.layers.each do |layer|
        print "Checking #{layer.name}... "

        existing = layer.existing(model.dis_type, objects)
        missing = objects - existing
        global_missing -= existing
        puts "#{existing.length} existing, #{missing.length} missing"

        next unless layer.delayed?

        jobs += (missing - global_missing).pmap do |hash|
          [model.dis_type, hash]
        end.compact
      end

      if global_missing.any?
        puts "\n#{global_missing.length} objects are missing from all layers:"
        pp global_missing
      end

      puts
    end

    if jobs.any?
      print "#{jobs.length} objects can be transferred to delayed layers, " \
            "queue now? (y/n) "
      response = STDIN.gets.chomp
      if /^y/i.match?(response)
        puts "Queueing jobs..."
        jobs.each { |type, hash| Dis::Jobs::Store.perform_later(type, hash) }
      end
    end
  end
end
