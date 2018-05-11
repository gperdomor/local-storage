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
import Files

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
    private let directory: Folder

    /// Create a new Local adapter.
    ///
    /// - Parameters:
    ///   - worker: the EventLoop worker
    ///   - uploadDirectory: A path to the root directory from which to read or write files.
    public init(rootDirectory: String) throws {
        self.directory = try Folder(path: rootDirectory)
    }
}

extension LocalAdapter {
    /// See `copy`
    public func copy(object: String, from bucket: String, as targetObj: String, to targetBucket: String, on container: Container) throws -> EventLoopFuture<ObjectInfo> {
        let srcData = try self.directory.subfolder(named: bucket).file(named: object).read()

        return try self.create(object: targetObj, in: targetBucket, with: srcData, metadata: nil, on: container)
    }

    /// See `Adapter.create`
    public func create(object: String, in bucket: String, with content: Data, metadata: StorageMetadata?, on container: Container) throws -> EventLoopFuture<ObjectInfo> {
        let file = try self.directory.subfolder(named: bucket).createFile(named: object, contents: content)

        let objectInfo = ObjectInfo(
            name: object,
            prefix: nil,
            size: file.size(),
            etag: try MD5.hash(content).hexEncodedString(),
            lastModified: file.modificationDate,
            url: file.path.convertToURL()
        )

        return Future.map(on: container) { objectInfo }
    }

    /// See `delete`
    public func delete(object: String, in bucket: String, on container: Container) throws -> EventLoopFuture<Void> {
        try self.directory.subfolder(named: bucket).file(named: object).delete()

        return Future.map(on: container) { () }
    }

    public func get(object: String, in bucket: String, on container: Container) throws -> EventLoopFuture<Data> {
        let data = try self.directory.subfolder(named: bucket).file(named: object).read()

        return Future.map(on: container) { data }
    }
}

extension LocalAdapter {
    public func create(bucket: String, metadata: StorageMetadata?, on container: Container) throws -> EventLoopFuture<Void> {
        if self.directory.containsSubfolder(named: bucket) {
            throw LocalAdapterError(identifier: "create bucket", reason: "Bucket '\(bucket)' already exists.", source: .capture())
        }

        try self.directory.createSubfolder(named: bucket)

        return Future.map(on: container) { () }
    }

    public func delete(bucket: String, on container: Container) throws -> EventLoopFuture<Void> {
        guard self.directory.containsSubfolder(named: bucket) else {
            throw LocalAdapterError(identifier: "delete bucket", reason: "Bucket '\(bucket)' not exists.", source: .capture())
        }

        let bucketFolder = try self.directory.subfolder(named: bucket)

        guard bucketFolder.files.count == 0, bucketFolder.subfolders.count == 0 else {
            throw LocalAdapterError(identifier: "delete bucket", reason: "Bucket '\(bucket)' is not empty.", source: .capture())
        }

        try bucketFolder.delete()

        return Future.map(on: container) { () }
    }

    public func get(bucket: String, on container: Container) throws -> EventLoopFuture<BucketInfo?> {
        guard self.directory.containsSubfolder(named: bucket) else {
            throw LocalAdapterError(identifier: "get bucket", reason: "Bucket '\(bucket)' not exists.", source: .capture())
        }

        let bucketFolder = try self.directory.subfolder(named: bucket)

        return Future.map(on: container) { BucketInfo(name: bucket, creationDate: bucketFolder.creationDate()) }
    }

    public func list(on container: Container) throws -> EventLoopFuture<[BucketInfo]> {
        let buckets = self.directory.subfolders.map { BucketInfo(name: $0.name, creationDate: $0.creationDate()) }

        return Future.map(on: container) { buckets }
    }

    public func listObjects(in bucket: String, prefix: String?, on container: Container) throws -> EventLoopFuture<[ObjectInfo]> {
        guard self.directory.containsSubfolder(named: bucket) else {
            throw LocalAdapterError(identifier: "listObjects", reason: "Bucket '\(bucket)' not exists.", source: .capture())
        }

        let bucketFolder = try self.directory.subfolder(named: bucket)

        let objects: [ObjectInfo] = try bucketFolder.files.compactMap {
            if let p = prefix {
                if !$0.name.hasPrefix(p) {
                    return nil
                }
            }

            let data = try $0.read()
            return try ObjectInfo(name: $0.name, prefix: prefix, size: $0.size(), etag: MD5.hash(data).hexEncodedString(), lastModified: $0.modificationDate, url: $0.path.convertToURL())
        }

        return Future.map(on: container) { objects }
    }
}

extension FileSystem.Item {
    func creationDate() -> Date {
        let attributes = try! FileManager.default.attributesOfItem(atPath: path)
        return attributes[FileAttributeKey.creationDate] as! Date
    }
}

extension Files.File {
    func size() -> Int {
        let attributes = try! FileManager.default.attributesOfItem(atPath: path)
        return attributes[FileAttributeKey.size] as! Int
    }
}
