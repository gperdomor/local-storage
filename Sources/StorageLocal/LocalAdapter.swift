//
//  LocalAdapter.swift
//  StorageLocal
//
//  Created by Gustavo Perdomo on 4/16/18.
//  Copyright © 2018 Gustavo Perdomo. All rights reserved.
//

import Async
import Foundation
import StorageKit

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
    let directory: String

    /// Value to set if the directory should be created if not exist.
    /// Default: `false`.
    let create: Bool

    /// POSIX permission value to set when the directory is created.
    /// - note: Should be expressed as octal integer.
    /// Default: `0o755`.
    let mode: Int

    /// Create a new Local adapter.
    ///
    /// - Parameters:
    ///   - uploadDirectory: A path to the root directory from which to read or write files.
    ///   - create: `true` to create the directory if not exists.  Default: `false`.
    ///   - mode: POSIX permission as octal integer. Default: `0o755`.
    public init(uploadDirectory: URL, create: Bool = false, mode: Int = 0o755) {
        self.directory = "\(uploadDirectory.path)"
        self.create = create
        self.mode = mode
    }

    /// See Adapter.read
    public func read(at path: String) throws -> Data? {
        let computedPath = try self.compute(path: path)
        return FileManager.default.contents(atPath: computedPath)
    }

    /// See Adapter.write
    public func write(on worker: Worker, content: Data, at path: String) throws -> Future<StorageResult> {
        let computedPath = try self.compute(path: path)

        if try self.exists(at: computedPath) {
            // throw file already exist
        }

        let success = FileManager.default.createFile(atPath: computedPath, contents: content)

        return Future.map(on: worker) { StorageResult(success: success, response: nil) }
    }

    /// See Adapter.exists
    public func exists(at path: String) throws -> Bool {
        let computedPath = try self.compute(path: path)
        return FileManager.default.fileExists(atPath: computedPath)
    }

    /// See Adapter.list
    public func list() throws -> [String] {
        try self.ensureDirectoryExists(directory: self.directory, create: self.create)

        do {
            return try FileManager.default.contentsOfDirectory(atPath: self.directory)
        } catch {
            throw LocalAdapterError(identifier: "list", reason: error.localizedDescription, source: .capture())
        }
    }

    /// See Adapter.delete
    public func delete(on worker: Worker, at path: String) throws -> Future<StorageResult> {
        let computedPath = try self.compute(path: path)

        do {
            try FileManager.default.removeItem(atPath: computedPath)
            return Future.map(on: worker) { StorageResult(success: true, response: nil) }
        } catch {
            throw LocalAdapterError(identifier: "delete", reason: error.localizedDescription, source: .capture())
        }
    }

    /// See Adapter.rename
    public func rename(on worker: Worker, at path: String, to target: String) throws -> Future<StorageResult> {
        let computedSource = try self.compute(path: path)
        let computedTarget = try self.compute(path: target)

        do {
            try FileManager.default.moveItem(atPath: computedSource, toPath: computedTarget)
            return Future.map(on: worker) { StorageResult(success: true, response: nil) }
        } catch {
            throw LocalAdapterError(identifier: "rename", reason: error.localizedDescription, source: .capture())
        }
    }

    /// See Adapter.isDirectory
    public func isDirectory(at path: String) throws -> Bool {
        let computedPath = try self.compute(path: path)
        return self._isDirectory(at: computedPath)
    }

    /// Computes the path from the specified key.
    ///
    /// - Parameter path: The key which for to compute the path.
    /// - Returns: A path.
    /// - Throws: `LocalAdapterError` if the directory does not exists and could not  be created.
    private func compute(path: String) throws -> String {
        try self.ensureDirectoryExists(directory: self.directory, create: self.create)

        return "\(self.directory)/\(path)"
    }

    /// Check if the passed path exists.
    ///
    /// - Parameter path: A path.
    /// - Returns: Bool.
    private func _isDirectory(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    /// Ensures the specified directory exists, creates it if it does not.
    ///
    /// - Parameters:
    ///   - path: Path of the directory to test.
    ///   - create: Whether to create the directory if it does not exist.
    /// - Throws: `LocalAdapterError` if the directory does not exists and could not  be created.
    private func ensureDirectoryExists(directory path: String, create: Bool) throws {
        if !self._isDirectory(at: path) {
            if !create {
                throw LocalAdapterError(
                    identifier: "ensureDirectoryExists",
                    reason: "The directory '\(path)' does not exist.",
                    source: .capture()
                )
            }
        }

        try self.create(directory: path, mode: self.mode)
    }

    /// Creates the specified directory and its parents.
    ///
    /// - Parameters:
    ///   - path: Path of the directory to create.
    ///   - mode: Posix permission.
    /// - Throws: `LocalAdapterError`if the directory could not be created.
    private func create(directory path: String, mode: Int) throws {
        do {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: [FileAttributeKey.posixPermissions: mode]
            )
        } catch {
            throw LocalAdapterError(
                identifier: "create",
                reason: "The directory '\(path)' could not be created",
                source: .capture()
            )
        }
    }
}
