//
//  StorageLocalTests.swift
//  StorageLocal
//
//  Created by Gustavo Perdomo on 4/16/18.
//  Copyright © 2018 Gustavo Perdomo. All rights reserved.
//

import XCTest
@testable import StorageLocal

final class StorageLocalTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(StorageLocal().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample)
    ]
}
