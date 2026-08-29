# Changelog

## [2.2.2](https://github.com/elektronaut/dis/compare/dis/v2.2.1...dis/v2.2.2) (2026-08-29)


### Bug Fixes

* release the file on abort rather than close ([6c86656](https://github.com/elektronaut/dis/commit/6c8665675b57220322e7013b43160deecf97db58))
* release the file on abort rather than close ([d08abbc](https://github.com/elektronaut/dis/commit/d08abbc103bc28f94538d2c5f7ce919f70459fa5))

## [2.2.1](https://github.com/elektronaut/dis/compare/dis/v2.2.0...dis/v2.2.1) (2026-08-29)


### Bug Fixes

* count content_length in bytes, size uploads without reading ([ce4baf5](https://github.com/elektronaut/dis/commit/ce4baf5b224eeb805cbd36cb907989ad157cc6a4))
* count content_length in bytes, size uploads without reading ([f7308ad](https://github.com/elektronaut/dis/commit/f7308ad461755508e99b0f1d3b702e3f7dadc4b1))

## [2.2.0](https://github.com/elektronaut/dis/compare/dis/v2.1.0...dis/v2.2.0) (2026-08-29)


### Features

* send multiple ranges as multipart/byteranges ([30f1fee](https://github.com/elektronaut/dis/commit/30f1fee765416035696d064b3e007d26b14b4cf7))
* support range requests in send_dis_data ([d24fbcf](https://github.com/elektronaut/dis/commit/d24fbcf405265d6600f4552a8e790f36c3289843))
* support range requests in send_dis_data ([58e7a80](https://github.com/elektronaut/dis/commit/58e7a80d67ab76a61fcd8902484b31dd968ba3f8))

## [2.1.0](https://github.com/elektronaut/dis/compare/dis/v2.0.0...dis/v2.1.0) (2026-08-29)


### Features

* add send_dis_data for streaming stored data from controllers ([45be0d5](https://github.com/elektronaut/dis/commit/45be0d58061a3ff580571770db8025aa794973fd))

## [2.0.0](https://github.com/elektronaut/dis/compare/dis/v1.3.1...dis/v2.0.0) (2026-08-29)


### Miscellaneous Chores

* release 2.0.0 ([2d39ce6](https://github.com/elektronaut/dis/commit/2d39ce6caaa46fdfcfb84cd74fd5dfc26288a419))

## [1.3.1](https://github.com/elektronaut/dis/compare/dis/v1.3.0...dis/v1.3.1) (2026-08-29)


### Bug Fixes

* refresh cached file mtime on path-based reads ([f7c35c4](https://github.com/elektronaut/dis/commit/f7c35c483ac26dc137235de8df7dceab9f70e994))
* refresh cached file mtime on path-based reads ([78d8e87](https://github.com/elektronaut/dis/commit/78d8e87cddaec3d3694cfddc5f68ef0fe6f8b849))

## [1.3.0](https://github.com/elektronaut/dis/compare/dis/v1.2.0...dis/v1.3.0) (2026-02-22)


### Features

* add bounded cache layer with LRU eviction ([d8334ab](https://github.com/elektronaut/dis/commit/d8334abcd72a052a2fbb8781048fc7937ef3ee61))
* add dis:missing and dis:orphaned rake tasks ([dd932ce](https://github.com/elektronaut/dis/commit/dd932ced8b05403c92259e50116f76507f734809))
* add dis:missing and dis:orphaned rake tasks ([ccf02a4](https://github.com/elektronaut/dis/commit/ccf02a489e74fdbcd319b3887240dfe9eb5ecc66))
* handle layer availability issues on reads ([b5533a7](https://github.com/elektronaut/dis/commit/b5533a7e5bb4b9b945b5e20cc75b05ab96469255)), closes [#11](https://github.com/elektronaut/dis/issues/11)

## [1.2.0](https://github.com/elektronaut/dis/compare/dis/v1.1.21...dis/v1.2.0) (2026-02-20)


### Features

* add Data#reset_read_cache\! to release cached data from memory ([e9d4be2](https://github.com/elektronaut/dis/commit/e9d4be2e14a32e3d84a49746063e85bdf04a65f4))
* add file_path access for local storage ([6bc6e5f](https://github.com/elektronaut/dis/commit/6bc6e5f776d367689f99bef8456d1c9bc48dd43d))


### Bug Fixes

* use hash comparison in Data#== for stored objects ([982cb77](https://github.com/elektronaut/dis/commit/982cb7732c2c1a22e35aee8cefc32ffdd1c5b42c))

## [1.1.21](https://github.com/elektronaut/dis/compare/dis/v1.1.20...dis/v1.1.21) (2026-02-03)


### Bug Fixes

* handle nil in Data#== comparison ([735eb41](https://github.com/elektronaut/dis/commit/735eb41d51c51eedf1352ae7afb940c8a3a63818))
* make discard_on work in Store job ([3074916](https://github.com/elektronaut/dis/commit/3074916d57be86ba372c1da75555399c649e35fa))

## [1.1.20](https://github.com/elektronaut/dis/compare/dis/v1.1.19...dis/v1.1.20) (2026-01-22)


### Bug Fixes

* Combine release-please and publish in same workflow ([4c5a1d6](https://github.com/elektronaut/dis/commit/4c5a1d6ad9120328609f8d72d5cc6b8420493e1e))

## [1.1.19](https://github.com/elektronaut/dis/compare/dis/v1.1.18...dis/v1.1.19) (2026-01-22)


### Bug Fixes

* Install dependencies before publishing gem ([236b0a6](https://github.com/elektronaut/dis/commit/236b0a6dfacca918b6d26767cc0c724fa0650dfd))

## [1.1.18](https://github.com/elektronaut/dis/compare/dis-v1.1.17...dis/v1.1.18) (2026-01-21)


### Bug Fixes

* Add package-name to enable Gemfile.lock updates ([5c982ce](https://github.com/elektronaut/dis/commit/5c982ceb9cab8038a64a3083ad69119883d6ffc6))
* Add release-please config ([b5205f3](https://github.com/elektronaut/dis/commit/b5205f364a3273c57e44fb4f95cee2f3b3f94bd0))
* Build on Ruby 4.0 ([6d7c1bd](https://github.com/elektronaut/dis/commit/6d7c1bd91c8a0ee7845636fe8839005cdafef388))
* Fix build when updating version ([24da9e7](https://github.com/elektronaut/dis/commit/24da9e7e0b552c623e40e30ab6c22cd8d2776c66))
* Update release-please to handle Gemfile.lock version ([2b26fc0](https://github.com/elektronaut/dis/commit/2b26fc059f314637abaee36d6a806a24009fce25))

## [1.1.17](https://github.com/elektronaut/dis/compare/v1.1.16...v1.1.17) (2026-01-21)


### Bug Fixes

* Add release-please config ([b5205f3](https://github.com/elektronaut/dis/commit/b5205f364a3273c57e44fb4f95cee2f3b3f94bd0))
* Build on Ruby 4.0 ([6d7c1bd](https://github.com/elektronaut/dis/commit/6d7c1bd91c8a0ee7845636fe8839005cdafef388))
