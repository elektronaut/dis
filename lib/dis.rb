# frozen_string_literal: true

require "benchmark"
require "digest/sha1"
require "fog/core"
require "fog/local"
require "active_job"
require "active_support/core_ext/module/attribute_accessors"
require "concurrent"
require "dis/controller"
require "dis/engine"
require "dis/errors"
require "dis/jobs"
require "dis/logging"
require "dis/layer"
require "dis/layers"
require "dis/model"
require "dis/response_body"
require "dis/storage"
require "dis/validations"

# Dis is a content-addressable store for file uploads in Rails.
#
# Files are stored as binary blobs keyed by the SHA1 digest of their
# contents, enabling automatic deduplication. Storage is organized in
# layers (see {Dis::Layer}) that can target local disk or any cloud
# provider supported by Fog.
#
# Include {Dis::Model} in an ActiveRecord model to get started, and
# configure layers via {Dis::Storage.layers}.
#
# @see Dis::Model
# @see Dis::Controller
# @see Dis::Storage
# @see Dis::Layer
module Dis
  # The ActiveJob queue used by delayed and cache layers. Defaults to
  # nil, which means jobs run on the ActiveJob default queue. Set it
  # to run them on a dedicated queue instead, either directly or with
  # <tt>config.dis.queue</tt>.
  #
  # Note that your job backend must be configured to process the
  # queue you choose. Sidekiq, Resque and Que only process a single
  # named queue unless told otherwise.
  #
  # @return [String, Symbol, nil] the queue name
  #
  # @example
  #   Dis.queue = :dis
  mattr_accessor :queue
end
