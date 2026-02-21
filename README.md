[![Version](https://img.shields.io/gem/v/dis.svg?style=flat)](https://rubygems.org/gems/dis)
![Build](https://github.com/elektronaut/dis/workflows/Build/badge.svg)

# Dis

Dis is a content-addressable store for file uploads in your Rails app.

Data can be stored either on disk or in the cloud — anywhere
[Fog](http://fog.io) can connect to.

It doesn't do any processing, but provides a simple foundation for
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

By default, files will be stored in `db/dis`. You can edit
`config/initializers/dis.rb` if you want to change the path or add
additional layers. Note that you also need the corresponding
[Fog gem](https://github.com/fog) if you want to use cloud storage:

```ruby
gem "fog-aws"
```

## Usage

Run the generator to create your model.

```sh
bin/rails generate dis:model Document
```

This will create a model along with a migration.

Here's what your model might look like. Note that Dis does not
validate any data by default, but you can use the standard Rails validators.
A validator for validating presence of data is provided.

```ruby
class Document < ActiveRecord::Base
  include Dis::Model
  validates_data_presence
  validates :content_type, presence: true, format: /\Aapplication\/(x\-)?pdf\z/
  validates :filename, presence: true, format: /\A[\w_\-\.]+\.pdf\z/i
  validates :content_length, numericality: { less_than: 5.megabytes }
end
```

To save your document, simply set the `file` attribute.

```ruby
document_params = params.require(:document).permit(:file)
@document = Document.create(document_params)
```

You can also pass a file directly:

```ruby
Document.create(data: File.open('document.pdf'),
                content_type: 'application/pdf',
                filename: 'document.pdf')
```

...or even a string:

```ruby
Document.create(data: 'foo', content_type: 'text/plain', filename: 'foo.txt')
```

Getting your file back out is straightforward:

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

The underlying storage consists of one or more layers. A layer is a
unit of storage location, which can either be a local path, or a cloud
provider like Amazon S3 or Google Cloud Storage.

There are three types of layers:

- **Immediate** layers are written to synchronously during the
  request cycle.
- **Delayed** layers are replicated in the background using ActiveJob.
- **Cache** layers are bounded, immediate layers with LRU eviction.
  They act as both a read cache and an upload buffer.

Reads are performed from the first available layer. In case of a read
miss, the file is backfilled from the next layer.

An example configuration could be to have a local layer first, and
then for example an Amazon S3 bucket. This provides you with an
on-disk cache backed by cloud storage. You can also add additional
layers if you want fault tolerance across regions or even providers.

Layers can be configured as read-only. This can be useful if you want
to read from your staging or production environment while developing
locally, or if you're transitioning away from a provider.

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

You can interact directly with the store if you want.

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
[MIT License](MIT-LICENSE).
