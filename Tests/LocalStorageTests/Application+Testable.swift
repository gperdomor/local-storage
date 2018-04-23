//
//  Application+Testable.swift
//  Async
//
//  Created by Gustavo Perdomo on 4/19/18.
//

import Vapor

extension Application {
    static func testable(envArgs: [String]? = nil) throws -> Application {
        var config = Config.default()
        var services = Services.default()
        var env = Environment.testing

        if let environmentArgs = envArgs {
            env.arguments = environmentArgs
        }

        let app = try Application(config: config, environment: env, services: services)

        return app
    }
}
