# Shrouded [![Build Status](https://travis-ci.org/elektronaut/shrouded.png)](https://travis-ci.org/elektronaut/shrouded) [![Code Climate](https://codeclimate.com/github/elektronaut/shrouded.png)](https://codeclimate.com/github/elektronaut/shrouded) [![Code Climate](https://codeclimate.com/github/elektronaut/shrouded/coverage.png)](https://codeclimate.com/github/elektronaut/shrouded)

**Warning:** Work in progress, the API is subject to change.

Shrouded handles file uploads for your Rails app.
It's similar to [Paperclip](https://github.com/thoughtbot/paperclip)
and [Carrierwave](https://github.com/carrierwaveuploader/carrierwave),
but different in a few ways. Chiefly, it's much, much simpler.

Your files are stored in one or more layers, either on disk or in
a cloud somewhere. [Fog](http://fog.io) and
[Active Job](https://github.com/rails/activejob) does most of the
heavy lifting.

Files are indexed by the SHA1 hash of their contents. This means you get
deduplication for free. This also means you run the (very slight) risk of
hash collisions. There is no concept of updates in the data store,
a file with changed content is by definition a different file.

It does not do any processing. The idea is to provide a simple foundation
other gems can build on. If you are looking to handle uploaded images,
the next version of
[DynamicImage](https://github.com/elektronaut/dynamic_image)
will be built on top of Shrouded.

Requires Rails 4.1+ and Ruby 1.9.3+.

## Installation

You know this:

```ruby
gem "shrouded"
```

## Usage

When the generator has been implemented, you will be able to do:

```sh
rails generate shrouded:model Document
```

This will create a model along with a migration.

Here's what your model might look like. Note that Shrouded does not
validate any data by default, you are expected to use the Rails validators.
A validator for validating presence of data is provided.

```ruby
class Document < ActiveRecord::Base
  include Shrouded::Model
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

You can also assign the data directly.

```ruby
Document.create(
  data:         File.open('document.pdf'),
  content_type: 'application/pdf',
  filename:     'document.pdf'
)
```

## Defining layers

You'll want to configure your storage layers in an initializer.
You can have as many layers as you want, any storage provider
[supported by Fog](http://fog.io/storage/) should work in theory.
Having a local layer first is a good idea, this will provide you
with a cache on disk. Any misses will be filled from the next layer.

```ruby
Shrouded::Storage.layers << Shrouded::Layer.new(
  Fog::Storage.new({provider: 'Local', local_root: Rails.root.join('db', 'binaries')}),
  path: Rails.env
)
```

Delayed layers will be processed out of the request cycle using
whatever adapter you've configured
[Active Job](https://github.com/rails/activejob) to use.
Note: You must have at least one non-delayed layer.

```ruby
aws_store = Fog::Storage.new({
  provider:              'AWS',
  aws_access_key_id:     YOUR_AWS_ACCESS_KEY_ID,
  aws_secret_access_key: YOUR_AWS_SECRET_ACCESS_KEY
})

if Rails.env.production?
  Shrouded::Storage.layers << Shrouded::Layer.new(aws_store, delayed: true)
end
```

You can also set layers to be read only. This is handy if you want to
access production data from your development environment, or if you
are in the process of migration from one provider to another.

```ruby
if Rails.env.development?
  Shrouded::Storage.layers << Shrouded::Layer.new(aws_store, readonly: true)
end
```

## Interacting with the store

You can interact directly with the store if you want.

```ruby
file = File.open("foo.txt")
hash = Shrouded::Storage.store("stuff", file) # => "8843d7f92416211de9ebb963ff4ce28125932878"
Shrouded::Storage.exists?("stuff", hash)      # => true
Shrouded::Storage.get("stuff", hash).body     # => "foobar"
Shrouded::Storage.delete("stuff", hash)       # => true
```

## License

Copyright 2014 Inge Jørgensen

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.