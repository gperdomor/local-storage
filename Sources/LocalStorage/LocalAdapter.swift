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
}

extension LocalAdapter {
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

    internal func get(object: String, in bucket: String) throws -> Data {
        let path = self.compute(bucket: bucket, object: object)

        guard let data = fm.contents(atPath: path) else {
            throw LocalAdapterError(identifier: "get object", reason: "can't retrieve object.", source: .capture())
        }

        return data
    }

    internal func list() throws -> [BucketInfo] {
        guard let url = self.directory.convertToURL() else {
            throw LocalAdapterError(identifier: "list", reason: "unable to covert to URL", source: .capture())
        }

        let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [.skipsSubdirectoryDescendants])

        let buckets: [BucketInfo] = try contents.compactMap {
            let path = $0.path
            let name = $0.lastPathComponent

            print("\(path) - \(self.isDirectory(at: path))")

            if !name.hasPrefix(".") && self.isDirectory(at: path) == true {
                let attr = try fm.attributesOfItem(atPath: path)
                return BucketInfo(name: name, creationDate: Date(rfc1123: attr[.creationDate] as? String ?? ""))
            }

            return nil
        }

        return buckets
    }

    internal func listObjects(in bucket: String, prefix: String? = nil) throws -> [ObjectInfo] {
        guard let url = self.compute(bucket: bucket).convertToURL() else {
            throw LocalAdapterError(identifier: "listObjects", reason: "unable to covert to URL", source: .capture())
        }

        let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [.skipsSubdirectoryDescendants])
        let prefix: String = prefix ?? ""

        let objects: [ObjectInfo] = try contents.compactMap {
            let path = $0.path
            let name = $0.lastPathComponent

            if !name.hasPrefix(".") && !name.hasPrefix(prefix) {
                return nil
            }

            let attr = try fm.attributesOfItem(atPath: path)

            return ObjectInfo(
                name: name,
                prefix: prefix,
                size: attr[.size] as? Int,
                etag: try MD5.hash(self.get(object: name, in: bucket)).hexEncodedString(),
                lastModified: Date(rfc1123: attr[.creationDate] as? String ?? ""),
                url: nil
            )
        }

        return objects
    }

    /// Verify if the path is a directory.
    ///
    /// - Parameter path: the path.
    /// - Returns: `true` if the path exists and is a directory, `false` in other cases`.
    internal func isDirectory(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        fm.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

extension LocalAdapter {
    /// See `copy`
    public func copy(object: String, from bucket: String, as targetObj: String, to targetBucket: String, on container: Container) throws -> EventLoopFuture<ObjectInfo> {
        let source = self.compute(bucket: bucket, object: object)
        let target = self.compute(bucket: targetBucket, object: targetObj)

        try self.fm.copyItem(atPath: source, toPath: target)

        let data = try self.get(object: targetObj, in: targetBucket)

        let objectInfo = ObjectInfo(
            name: targetObj,
            prefix: nil,
            size: data.count,
            etag: try MD5.hash(data).hexEncodedString(),
            lastModified: Date(),
            url: nil
        )

        return Future.map(on: container) { objectInfo }
    }

    /// See `Adapter.create`
    public func create(object: String, in bucket: String, with content: Data, metadata: StorageMetadata?, on container: Container) throws -> EventLoopFuture<ObjectInfo> {
        let path = self.compute(bucket: bucket, object: object)

        self.fm.createFile(atPath: path, contents: content)

        let objectInfo = ObjectInfo(
            name: object,
            prefix: nil,
            size: content.count,
            etag: try MD5.hash(content).hexEncodedString(),
            lastModified: Date(),
            url: nil
        )

        return Future.map(on: container) { objectInfo }
    }

    /// See `delete`
    public func delete(object: String, in bucket: String, on container: Container) throws -> EventLoopFuture<Void> {
        let path = self.compute(bucket: bucket, object: object)

        try fm.removeItem(atPath: path)

        return Future.map(on: container) { () }
    }

    public func get(object: String, in bucket: String, on container: Container) throws -> EventLoopFuture<Data> {
        let data = try self.get(object: object, in: bucket)

        return Future.map(on: container) { data }
    }
}

extension LocalAdapter {
    public func create(bucket: String, metadata: StorageMetadata?, on container: Container) throws -> EventLoopFuture<Void> {
        if try self.get(bucket: bucket) != nil {
            throw LocalAdapterError(identifier: "create bucket", reason: "Bucket '\(bucket)' already exists.", source: .capture())
        }

        let path = self.compute(bucket: bucket)

        try self.create(directory: path, mode: mode)

        return Future.map(on: container) { () }
    }

    public func delete(bucket: String, on container: Container) throws -> EventLoopFuture<Void> {
        let path = self.compute(bucket: bucket)

        guard try fm.contentsOfDirectory(atPath: path).isEmpty else {
            throw LocalAdapterError(identifier: "delete bucket", reason: "Bucket '\(bucket)' is not empty.", source: .capture())
        }

        try self.delete(directory: path)

        return Future.map(on: container) { () }
    }

    public func get(bucket: String, on container: Container) throws -> EventLoopFuture<BucketInfo?> {
        let bucketInfo = try self.get(bucket: bucket)

        return Future.map(on: container) { bucketInfo }
    }

    public func list(on container: Container) throws -> EventLoopFuture<[BucketInfo]> {
        let buckets = try self.list()

        return Future.map(on: container) { buckets }
    }

    /// See `Adapter.listObjects`
    public func listObjects(in bucket: String, prefix: String?, on container: Container) throws -> EventLoopFuture<[ObjectInfo]> {
        let objects = try self.listObjects(in: bucket, prefix: prefix)

        return Future.map(on: container) { objects }
    }
}
