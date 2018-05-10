// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "LocalStorage",
    products: [
        .library(name: "LocalStorage", targets: ["LocalStorage"])
    ],
    dependencies: [
        // 🗄 Storage abstraction framework.
        .package(url: "https://github.com/gperdomor/storage-kit.git", from: "0.2.1")
    ],
    targets: [
        .target(name: "LocalStorage", dependencies: ["StorageKit"]),
        .testTarget(name: "LocalStorageTests", dependencies: ["LocalStorage"])
    ]
)
