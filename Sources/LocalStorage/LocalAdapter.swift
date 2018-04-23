//
//  LocalAdapter.swift
//  LocalStorage
//
//  Created by Gustavo Perdomo on 4/16/18.
//  Copyright © 2018 Gustavo Perdomo. All rights reserved.
//

import Async
import Crypto
import Foundation
import StorageKit
import Vapor

extension AdapterIdentifier {
    /// The main Local adapter identifier.
    public static var local: AdapterIdentifier<LocalAdapter> {
        return .init("local")
    }
}

/// `LocalAdapter` provides an interface that allows handle files
/// in the local filesystem.
public class LocalAdapter: Adapter {
    /// A path to the root directory from which to read or write files.
    private let directory: String

    /// POSIX permission value to set when the directory is created.
    /// - note: Should be expressed as octal integer.
    /// Default: `0o755`.
    private let mode: Int

    private let fm = FileManager.default

    /// Create a new Local adapter.
    ///
    /// - Parameters:
    ///   - worker: the EventLoop worker
    ///   - uploadDirectory: A path to the root directory from which to read or write files.
    ///   - mode: POSIX permission as octal integer. Default: `0o755`.
    public init(rootDirectory: URL, create: Bool, mode: Int = 0o755) throws {
        self.directory = "\(rootDirectory.path)"
        self.mode = mode

        if create {
            try self.create(directory: self.directory, mode: mode)
        }
    }

    // MARK: Bucket Operations

    /// See `Adapter.create`
    public func create(bucket: String, metadata: Codable? = nil, on container: Container) throws -> Future<Void> {
        if try self.get(bucket: bucket) != nil {
            throw LocalAdapterError(identifier: "create bucket", reason: "Bucket '\(bucket)' already exists.", source: .capture())
        }

        let path = self.compute(bucket: bucket)

        try self.create(directory: path, mode: mode)

        return Future.map(on: container) { () }
    }

    /// See `Adapter.delete`
    public func delete(bucket: String, on container: Container) throws -> Future<Void> {
        let path = self.compute(bucket: bucket)

        guard try fm.contentsOfDirectory(atPath: path).isEmpty else {
            throw LocalAdapterError(identifier: "delete bucket", reason: "Bucket '\(bucket)' is not empty.", source: .capture())
        }

        try self.delete(directory: path)

        return Future.map(on: container) { () }
    }

    /// See `Adapter.get`
    public func get(bucket: String, on container: Container) throws -> Future<BucketInfo?> {
        let bucketInfo = try self.get(bucket: bucket)

        return Future.map(on: container) { bucketInfo }
    }

    /// See `Adapter.list`
    public func list(on container: Container) throws -> Future<[BucketInfo]> {
        let buckets = try self.list()

        return Future.map(on: container) { buckets }
    }

    // MARK: Object Operations

    /// See `Adapter.copy`
    public func copy(object sourceObj: String, from sourceBucket: String, as targetObj: String, to targetBucket: String, on container: Container) throws -> Future<ObjectInfo> {
        let source = self.compute(bucket: sourceBucket, object: sourceObj)
        let target = self.compute(bucket: targetBucket, object: targetObj)

        try fm.copyItem(atPath: source, toPath: target)

        let data = try self.get(object: targetObj, in: targetBucket)

        let objectInfo = ObjectInfo(
            name: targetObj,
            prefix: nil,
            size: data.count,
            etag: try MD5.hash(data).hexEncodedString(),
            lastModified: Date()
        )

        return Future.map(on: container) { objectInfo }
    }

    /// See `Adapter.create`
    public func create(object: String, in bucket: String, with content: Data, metadata: Codable? = nil, on container: Container) throws -> Future<ObjectInfo> {
        let path = self.compute(bucket: bucket, object: object)

        fm.createFile(atPath: path, contents: content)

        let objectInfo = ObjectInfo(
            name: object,
            prefix: nil,
            size: content.count,
            etag: try MD5.hash(content).hexEncodedString(),
            lastModified: Date()
        )

        return Future.map(on: container) { objectInfo }
    }

    /// See `Adapter.delete`
    public func delete(object: String, in bucket: String, on container: Container) throws -> Future<Void> {
        let path = self.compute(bucket: bucket, object: object)

        try fm.removeItem(atPath: path)

        return Future.map(on: container) { () }
    }

    /// See `Adapter.get`
    public func get(object: String, in bucket: String, on container: Container) throws -> Future<Data> {
        let object = try self.get(object: object, in: bucket)

        return Future.map(on: container) { object }
    }

    /// See `Adapter.listObjects`
    public func listObjects(in bucket: String, prefix: String?, on container: Container) throws -> Future<[ObjectInfo]> {
        let objects = try self.listObjects(in: bucket, prefix: prefix)

        return Future.map(on: container) { objects }
    }

    // MARK: Helpers

    /// Build the path for the specified bucket and object.
    ///
    /// - Parameters:
    ///   - bucket: name of the bucket.
    ///   - object: name of the object.
    /// - Returns: The path
    internal func compute(bucket: String, object: String? = nil) -> String {
        var composed = "\(self.directory)/\(bucket)"

        if let object = object, !object.isEmpty {
            composed += "/\(object)"
        }

        return composed
    }

    /// Creates the specified directory and its parents.
    ///
    /// - Parameters:
    ///   - path: Path of the directory to create.
    ///   - mode: Posix permission.
    /// - Throws: <#throws value description#>
    internal func create(directory path: String, mode: Int) throws {
        try fm.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: [:]
        )
    }

    /// <#Description#>
    ///
    /// - Parameter path: <#path description#>
    /// - Throws: <#throws value description#>
    internal func delete(directory path: String) throws {
        try fm.removeItem(atPath: path)
    }

    /// <#Description#>
    ///
    /// - Parameter bucket: <#bucket description#>
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    internal func get(bucket: String) throws -> BucketInfo? {
        let buckets = try self.list()

        return buckets.first(where: { buck in
            buck.name == bucket
        })
    }

    internal func list() throws -> [BucketInfo] {
        // FIX froce unwraping
        let url = URL(string: self.directory)!

        let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])

        let buckets: [BucketInfo] = try contents.compactMap {
            let values = try $0.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey])

            if(values.isDirectory == true) {
                return BucketInfo(name: $0.lastPathComponent, creationDate: values.creationDate)
            }

            return nil
        }

        return buckets
    }

    internal func get(object: String, in bucket: String) throws -> Data {
        let path = self.compute(bucket: bucket, object: object)

        guard let data = fm.contents(atPath: path) else {
            throw LocalAdapterError(identifier: "get object", reason: "can't retrieve object.", source: .capture())
        }

        return data
    }

    internal func listObjects(in bucket: String, prefix: String? = nil) throws -> [ObjectInfo] {
        // FIX froce unwraping
        let path = self.compute(bucket: bucket)

        let url = URL(string: path)!
        let prefix: String = prefix ?? ""

        let contents = try fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey],
            options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        )

        let objects: [ObjectInfo] = try contents.compactMap {
            let values = try $0.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey])

            let name = $0.lastPathComponent

            if !name.hasPrefix(prefix) {
                return nil
            }

            return ObjectInfo(
                name: name,
                prefix: prefix,
                size: values.fileSize,
                etag: try MD5.hash(self.get(object: name, in: bucket)).hexEncodedString(),
                lastModified: values.creationDate
            )
        }

        return objects
    }

//    /// Verify if the path is a directory.
//    ///
//    /// - Parameter path: the path.
//    /// - Returns: `true` if the path exists and is a directory, `false` in other cases`.
//    internal func isDirectory(at path: String) -> Bool {
//        var isDirectory: ObjCBool = false
//        fm.fileExists(atPath: path, isDirectory: &isDirectory)
//        return isDirectory.boolValue
//    }
}
