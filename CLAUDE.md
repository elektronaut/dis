# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Dis is a content-addressable file storage gem for Rails. Files are stored as binary blobs keyed by SHA1 digest of their contents, enabling automatic deduplication. Supports multiple storage layers (local disk + cloud via Fog) with immediate writes to fast layers and asynchronous replication to slower layers via ActiveJob.

## Commands

```bash
bundle exec rspec                              # Run all tests
bundle exec rspec spec/dis/model_spec.rb       # Run single test file
bundle exec rspec spec/dis/model_spec.rb:27    # Run test at specific line
bundle exec rubocop                            # Lint
```

## Architecture

### Storage Layer Design

`Dis::Storage` is the static entry point for all operations (store, get, delete, exists?). It manages a `Dis::Layers` collection, where each `Dis::Layer` wraps a `Fog::Storage` connection.

Layers have three dimensions:
- **Immediate vs delayed** — Immediate layers are written synchronously; delayed layers are replicated via ActiveJob (`Dis::Jobs::Store`, `Dis::Jobs::Delete`, `Dis::Jobs::ChangeType` on queue `:dis`)
- **Writeable vs readonly** — Readonly layers can serve reads but won't receive writes
- **Backfill** — On read miss from fast layers, files are automatically copied back from slower layers

Directory structure within each layer: `{path}/{type}/{first_2_chars_of_hash}/{remaining_hash}`

### Model Integration

`Dis::Model` is an ActiveRecord concern providing the storage interface. Key lifecycle:
- `before_save :store_data` — writes to immediate layers
- `after_save :cleanup_data` — removes old hash if content changed and no other records reference it
- `after_destroy :delete_data` — deletes hash if unreferenced

`Dis::Model::Data` wraps the binary data with lazy loading, tempfile caching, and memory management (`reset_read_cache!`).

Models get attributes: `data`, `content_hash`, `content_type`, `content_length`, `filename`. Use `validates_data_presence` instead of `validates :data, presence: true` to avoid loading data from storage during validation.

### Input Handling

`data=` accepts File, String, IO, or Rack::UploadedFile. `file=` additionally extracts content_type and original_filename from uploaded files.

## Test Environment

Tests use an internal Rails app at `spec/internal/` with SQLite locally and PostgreSQL in CI. Models: `Image`, `ImageWithValidations`. Test fixture: `spec/support/fixtures/file.txt`.

## Rubocop

Max line length: 80 (auto-corrected). Plugins: rubocop-rails, rubocop-rspec, rubocop-rspec_rails. Target Ruby: 3.2.
