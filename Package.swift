// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "StorageLocal",
    products: [
        .library(name: "storage-local", targets: ["StorageLocal"])
    ],
    dependencies: [
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "StorageLocal", dependencies: []),
        .testTarget(name: "StorageLocalTests", dependencies: ["StorageLocal"])
    ]
)
