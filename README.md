[![Version](https://img.shields.io/gem/v/dis.svg?style=flat)](https://rubygems.org/gems/dis)
![Build](https://github.com/elektronaut/dis/workflows/Build/badge.svg)
[![Code Climate](https://codeclimate.com/github/elektronaut/dis/badges/gpa.svg)](https://codeclimate.com/github/elektronaut/dis)
[![Code Climate](https://codeclimate.com/github/elektronaut/dis/badges/coverage.svg)](https://codeclimate.com/github/elektronaut/dis)
[![Inline docs](http://inch-ci.org/github/elektronaut/dis.svg)](http://inch-ci.org/github/elektronaut/dis)
[![Security](https://hakiri.io/github/elektronaut/dis/main.svg)](https://hakiri.io/github/elektronaut/dis/main)

# Dis

Dis is a content-adressable store for file uploads in your Rails app.

Data can be stored either on disk or in the cloud - anywhere that
[Fog](http://fog.io) knows how to talk to.

It doesn't do any processing, but it's a simple foundation to roll
your own on. If you're looking to handle image uploads, check out
[DynamicImage](https://github.com/elektronaut/dynamic_image). It's
built on top of Dis and handles resizing, cropping and more on demand.

Requires Rails 5+

## Layers

The underlaying storage consists of one or more layers. A layer is a
unit of storage location, which can either be a local path, or a cloud
provider like Amazon S3 or Google Cloud Storage.

There are two types of layers, immediate and delayed. Files are
written to immediate layers and then replicated to the rest in the
background using ActiveJob.

Reads are performed from the first available layer. In case of a read
miss, the file is backfilled from the next layer.

An example configuration could be to have a local layer first, and
then for example an Amazon S3 bucket. This provides you with an
on-disk cache backed by cloud storage. You can also add additional
layers if you want fault tolerance across regions or even providers.

Layers can be configured as read-only. This can be useful if you want
to read from your staging or production environment while developing
locally, or if you're transitioning away from a provider.

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

..or even a string:

```ruby
Document.create(data: 'foo', content_type: 'text/plain', filename: 'foo.txt')
```

Getting your file back out is straightforward:

``` ruby
class DocumentsController < ApplicationController
  def show
    @document = Document.find(params[:id])
    if stale?(@document)
      send_data(@document.data,
                filename: @document.filename,
                type: @document.content_type,
                disposition: "attachment)
    end
  end
end
```

## Behind the scenes

You can interact directly with the store if you want.

```ruby
file = File.open("foo.txt")
hash = Dis::Storage.store("documents", file) # => "8843d7f92416211de9ebb963ff4ce28125932878"
Dis::Storage.exists?("documents", hash)      # => true
Dis::Storage.get("documents", hash).body     # => "foobar"
Dis::Storage.delete("documents", hash)       # => true
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
