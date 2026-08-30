[![Version](https://img.shields.io/gem/v/dis.svg?style=flat)](https://rubygems.org/gems/dis)
[![Build](https://github.com/elektronaut/dis/actions/workflows/build.yml/badge.svg)](https://github.com/elektronaut/dis/actions/workflows/build.yml)

# Dis

Dis is a content-addressable store for file uploads in your Rails app.

Files are stored as binary blobs, keyed by the SHA1 digest of their
contents. Storing the same file twice stores a single blob, the
second record simply points at the same hash. Deleting a record
deletes the blob only when no other record refers to it.

Data can be stored either on disk or in the cloud — anywhere
[Fog](http://fog.io) can connect to.

It doesn't do any processing, but provides a foundation for
building your own. If you're looking to handle image uploads, check out
[DynamicImage](https://github.com/elektronaut/dynamic_image). It's
built on top of Dis and handles resizing, cropping and more on demand.

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

Unless you intend to check your uploads into version control, add the
storage path to `.gitignore`:

```
/db/dis
```

## Getting started

Run the generator to create your model.

```sh
bin/rails generate dis:model Document
```

This creates a model along with a migration for the four attributes
Dis needs: `content_hash`, `content_type`, `content_length` and
`filename`.

Dis does not validate any data by default, but you can use standard
Rails validators. A presence validator for data is also provided; use
it rather than `validates :data, presence: true`, which would load the
data from storage on every save.

```ruby
class Document < ActiveRecord::Base
  include Dis::Model

  validates_data_presence
  validates :content_type, presence: true, format: /\Aapplication\/(x\-)?pdf\z/
  validates :filename, presence: true, format: /\A[\w_\-\.]+\.pdf\z/i
  validates :content_length, numericality: { less_than: 5.megabytes }
end
```

Assigning the upload to the `file` attribute stores it, and
`send_dis_data` streams it back to the client.

```ruby
class DocumentsController < ApplicationController
  include Dis::Controller

  def create
    @document = Document.create(params.expect(document: [:file]))
    redirect_to @document
  end

  def show
    @document = Document.find(params[:id])
    send_dis_data(@document) if stale?(@document)
  end
end
```

`send_dis_data` works like `send_file`, but reads through an open
descriptor rather than a path, so the response is unaffected if the
content is evicted or deleted while it is being written.

If the data can't be found in any layer, a `Dis::Errors::NotFoundError`
is raised.

## Writing data

When you assign `file` to an uploaded file, `content_type` and
`filename` are extracted automatically. You can also assign
`data` directly, but then you'll need to provide the metadata
yourself:

```ruby
Document.create(data: File.open("document.pdf"),
                content_type: "application/pdf",
                filename: "document.pdf")

Document.create(data: "foo", content_type: "text/plain", filename: "foo.txt")
```

Data is written to storage when the record is saved, and only if the
record is valid.

## Reading data

`data` returns the content as a binary string.

```ruby
document.data? # => true
document.data # => "foobar"
```

This loads the entire file into memory and keeps it there as long as
the record stays in scope, so be careful with this, particularly
when iterating over collections. The corresponding `data?` method is
a bit smarter and doesn't share this gotcha.

`open_data` returns an open file instead. It remains valid until you
close it, even if the content is deleted or evicted from a cache
layer. Use it when the reader outlives the current call stack, which
is how `send_dis_data` hands data off to the web server.

```ruby
# Yields an open file, then closes it
header = document.open_data { |file| file.read(1024) }

# Returns an open file, close it when you're done
file = document.open_data
file.close
```

`with_data_file` yields a path, for tools that want a file name rather
than the bytes. It is only valid for the duration of the block.

```ruby
document.with_data_file { |path| Vips::Image.new_from_file(path.to_s).avg }
```

## Storage layers

The underlying storage consists of one or more layers. Each layer
targets either a local path or a cloud provider like Amazon S3 or
Google Cloud Storage.

There are three types of layers:

- **Immediate** layers are written to synchronously during the
  request cycle.
- **Delayed** layers are replicated in the background using ActiveJob.
- **Cache** layers are bounded, immediate layers with LRU eviction.
  They act as both a read cache and an upload buffer.

Reads are attempted in the order the layers were added, and served
from the first one that has the file. If it had to be fetched from
further down, it is backfilled to every writeable immediate layer on
the way out.

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

At least one writeable, immediate layer is required. Operations raise
`Dis::Errors::NoLayersError` if none are configured.

Layers can also be configured as read-only, which is useful for
reading from staging or production while developing locally, or when
transitioning away from a provider.

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

## Configuration

### Background jobs

Delayed layers and cache eviction enqueue ActiveJob jobs. They run on
the ActiveJob default queue unless you tell Dis otherwise:

```ruby
Dis.queue = :dis # or config.dis.queue = :dis
```

### Storage type

Files are stored under a type, which defaults to the model's table
name and maps to a directory within each layer. Deduplication happens
within a type, so two different models storing the same file will each
have their own blob.

```ruby
class Document < ActiveRecord::Base
  include Dis::Model
  self.dis_type = "files"
end
```

Take care not to use the same `dis_type` for two models. They will share
blobs, and destroying a record in one model will delete data still
referenced by the other.

### Attribute names

If the default column names don't fit your schema, override them with
`dis_attributes`. Valid keys are `content_hash`, `content_type`,
`content_length` and `filename`.

```ruby
class Document < ActiveRecord::Base
  include Dis::Model
  self.dis_attributes = {
    filename: :my_filename,
    content_length: :filesize
  }
end
```

## Maintenance

Two rake tasks exist to help you audit the store. Both take a
comma-separated list of models.

```sh
bin/rails dis:missing MODELS=Document,Image    # records with no file
bin/rails dis:orphaned MODELS=Document,Image   # files with no record
```

`dis:missing` lists content hashes referenced by records that exist in
no non-cache layer. `dis:orphaned` lists the reverse, grouped by
layer: files in storage that no record refers to.

The same information is available programmatically:

```ruby
Dis::Storage.missing_keys(Document)  # => ["8843d7f9..."]
Dis::Storage.orphaned_keys(Document) # => { #<Dis::Layer> => ["8843d7f9..."] }
```

## Low-level API

You can also interact with the store directly.

```ruby
file = File.open("foo.txt")
hash = Dis::Storage.store("documents", file) # => "8843d7f92416211de9ebb963ff4ce28125932878"
Dis::Storage.exists?("documents", hash)      # => true
Dis::Storage.get("documents", hash).body     # => "foobar"
Dis::Storage.delete("documents", hash)       # => true
```

`get` loads the entire body into memory. To stream instead, write into
a file you own, or ask for a local path:

```ruby
File.open("out.txt", "w+b") do |file|
  Dis::Storage.get_file("documents", hash, file)
end

Dis::Storage.file_path("documents", hash) # => "/path/to/db/dis/..." or nil
```

`file_path` returns a path only if some layer holds the file locally.

To move content between types, use `change_type`:

```ruby
Dis::Storage.change_type("documents", "archived_documents", hash)
```

## Documentation

See the [generated documentation on RubyDoc.info](https://www.rubydoc.info/gems/dis),
and the [changelog](CHANGELOG.md) for release notes.

## Contributing

Bug reports and pull requests are welcome on
[GitHub](https://github.com/elektronaut/dis). See
[CONTRIBUTING.md](CONTRIBUTING.md) for how to run the tests and how
commits are formatted, and note that this project ships with a
[code of conduct](CODE_OF_CONDUCT.md).

## License

Released under the [MIT License](LICENSE).
