# frozen_string_literal: true

require "benchmark"
require "digest/sha1"
require "fog/core"
require "fog/local"
require "active_job"
require "concurrent"
require "dis/engine"
require "dis/errors"
require "dis/jobs"
require "dis/logging"
require "dis/layer"
require "dis/layers"
require "dis/model"
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
# @see Dis::Storage
# @see Dis::Layer
module Dis
end
