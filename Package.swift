// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "StorageLocal",
    products: [
        .library(name: "StorageLocal", targets: ["StorageLocal"])
    ],
    dependencies: [
        // 🗄 Storage abstraction framework.
        .package(url: "https://github.com/gperdomor/storage-kit.git", .branch("beta")),
    ],
    targets: [
        .target(name: "StorageLocal", dependencies: ["StorageKit"]),
        .testTarget(name: "StorageLocalTests", dependencies: ["StorageLocal"])
    ]
)
