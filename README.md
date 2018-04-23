[![Swift Version](https://img.shields.io/badge/Swift-4.1-brightgreen.svg)](https://swift.org)
[![Vapor Version](https://img.shields.io/badge/Vapor-3-brightgreen.svg)](https://vapor.codes)
[![Build Status](https://img.shields.io/circleci/project/github/gperdomor/local-storage.svg)](https://circleci.com/gh/gperdomor/local-storage)
[![codecov](https://codecov.io/gh/gperdomor/local-storage/branch/master/graph/badge.svg)](https://codecov.io/gh/gperdomor/local-storage)
[![GitHub license](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)

# LocalStorage

Storage driver using Local filesystem for Vapor 3.

This package is based on [StorageKit](https://github.com/gperdomor/storage-kit)

## Installation

Add this project to the `Package.swift` dependencies of your Vapor project:

```swift
  .package(url: "https://github.com/gperdomor/local-storage.git", from: "0.1.0")
```

## Setup

After you've added the LocalStorage package to your project, setting the provider up in code is easy.

### Service registration

First, register the LocalStorageProvider in your `configure.swift' file.

```swift
public func configure(
    _ config: inout Config,
    _ env: inout Environment,
    _ services: inout Services
) throws {
    /// Register providers first
    try services.register(LocalStorageProvider())

    // or whatever directory you want
    let rootDirectory = DirectoryConfig.detect().workDir

    // Add the adapter
    var adapters = AdapterConfig()
    adapters.add(adapter: try LocalAdapter(rootDirectory: URL(fileURLWithPath: "\(rootDirectory)Public/buckets"), create: true), as: .local)
    services.register(adapters)
}
```

## Use

```swift
struct BucketRequest: Content {
    let name: String
}

func create(_ req: Request, body: BucketRequest) throws -> Future<HTTPStatus> {
    let name = body.name

    return req.withStorage(to: AdapterIdentifier<LocalAdapter>.local) { storage in
        return try storage.create(bucket: name, on: req).transform(to: HTTPStatus.ok)
    }
}
```

## Learn More

* [StorageKit](https://github.com/gperdomor/storage-kit)

## Credits

This package is developed and maintained by [Gustavo Perdomo](https://github.com/gperdomor)

## License

LocalStorage is released under the [MIT License](LICENSE).
