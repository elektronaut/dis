[![Version](https://img.shields.io/gem/v/dis.svg?style=flat)](https://rubygems.org/gems/dis)
![Build](https://github.com/elektronaut/dis/workflows/Build/badge.svg)

# Dis

Dis is a content-addressable store for file uploads in your Rails app.

Data can be stored either on disk or in the cloud — anywhere
[Fog](http://fog.io) can connect to.

It doesn't do any processing, but provides a foundation for
building your own. If you're looking to handle image uploads, check out
[DynamicImage](https://github.com/elektronaut/dynamic_image). It's
built on top of Dis and handles resizing, cropping and more on demand.

## Requirements

- Ruby >= 3.2
- Rails >= 7.1

## Installation

Add the gem to your Gemfile and run `bundle install`:

```ruby
gem "dis"
```

Now, run the generator to install the initializer:

```sh
bin/rails generate dis:install
```

By default, files will be stored in `db/dis`. Edit
`config/initializers/dis.rb` to change the path or add
additional layers. Cloud storage requires the corresponding
[Fog gem](https://github.com/fog):

```ruby
gem "fog-aws"
```

## Usage

Run the generator to create your model.

```sh
bin/rails generate dis:model Document
```

This will create a model along with a migration.

Here's what your model might look like. Dis does not validate any data
by default, but you can use standard Rails validators. A presence
validator for data is also provided.

```ruby
class Document < ActiveRecord::Base
  include Dis::Model
  validates_data_presence
  validates :content_type, presence: true, format: /\Aapplication\/(x\-)?pdf\z/
  validates :filename, presence: true, format: /\A[\w_\-\.]+\.pdf\z/i
  validates :content_length, numericality: { less_than: 5.megabytes }
end
```

To save your document, set the `file` attribute. This extracts
`content_type` and `filename` from the upload automatically.

```ruby
document_params = params.require(:document).permit(:file)
@document = Document.create(document_params)
```

You can also assign `data` directly, but you'll need to set
`content_type` and `filename` yourself:

```ruby
Document.create(data: File.open("document.pdf"),
                content_type: "application/pdf",
                filename: "document.pdf")
```

...or even a string:

```ruby
Document.create(data: "foo", content_type: "text/plain", filename: "foo.txt")
```

Reading the file back out:

```ruby
class DocumentsController < ApplicationController
  def show
    @document = Document.find(params[:id])
    if stale?(@document)
      send_data(@document.data,
                filename: @document.filename,
                type: @document.content_type,
                disposition: "attachment")
    end
  end
end
```

## Layers

The underlying storage consists of one or more layers. Each layer
targets either a local path or a cloud provider like Amazon S3 or
Google Cloud Storage.

There are three types of layers:

- **Immediate** layers are written to synchronously during the
  request cycle.
- **Delayed** layers are replicated in the background using ActiveJob.
- **Cache** layers are bounded, immediate layers with LRU eviction.
  They act as both a read cache and an upload buffer.

Reads are performed from the first available layer. On a miss, the
file is backfilled from the next layer.

A typical multi-layer configuration has a local layer first and an
Amazon S3 bucket second. This gives you an on-disk cache backed by
cloud storage. Additional layers can provide fault tolerance across
regions or providers.

```ruby
# config/initializers/dis.rb

# Fast local layer (immediate, synchronous writes)
Dis::Storage.layers << Dis::Layer.new(
  Fog::Storage.new(provider: "Local", local_root: Rails.root.join("db/dis")),
  path: Rails.env
)

# Cloud layer (delayed, replicated via ActiveJob)
Dis::Storage.layers << Dis::Layer.new(
  Fog::Storage.new(
    provider: "AWS",
    aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
    aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
  ),
  path: "my-bucket",
  delayed: true
)
```

Layers can be configured as read-only — useful for reading from
staging or production while developing locally, or when transitioning
away from a provider.

### Cache layers

A cache layer provides bounded local storage with automatic eviction.
Files are evicted in LRU order, but only after they have been
replicated to at least one non-cache writeable layer. This ensures
unreplicated uploads are never lost.

The cache size is a soft limit: the cache may temporarily exceed it
if no files are safe to evict, and will shrink back once delayed
replication jobs complete.

```ruby
Dis::Storage.layers << Dis::Layer.new(
  Fog::Storage.new(provider: "Local", local_root: Rails.root.join("tmp/dis")),
  path: Rails.env,
  cache: 1.gigabyte
)
```

Cache layers cannot be combined with `delayed` or `readonly`.

## Low-level API

You can also interact with the store directly.

```ruby
file = File.open("foo.txt")
hash = Dis::Storage.store("documents", file) # => "8843d7f92416211de9ebb963ff4ce28125932878"
Dis::Storage.exists?("documents", hash)      # => true
Dis::Storage.get("documents", hash).body     # => "foobar"
Dis::Storage.delete("documents", hash)       # => true
```

## Documentation

See the [generated documentation on RubyDoc.info](https://www.rubydoc.info/gems/dis)

## License

Copyright 2014-2026 Inge Jørgensen. Released under the
[MIT License](LICENSE).
