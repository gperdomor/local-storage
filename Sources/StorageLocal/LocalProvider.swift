//
//  LocalProvider.swift
//  StorageLocal
//
//  Created by Gustavo Perdomo on 4/16/18.
//  Copyright © 2018 Gustavo Perdomo. All rights reserved.
//

import Service

/// Registers and boots Local Adapter services.
public final class StorageLocalProvider: Provider {
    /// See Provider.repositoryName
    public static let repositoryName = "storage-local"

    /// Create a new Local provider.
    public init() { }

    /// See Provider.register
    public func register(_ services: inout Services) throws {
        try services.register(StorageProvider())
    }

    /// See Provider.boot
    public func didBoot(_ container: Container) throws -> Future<Void> {
        return .done(on: container)
    }
}
