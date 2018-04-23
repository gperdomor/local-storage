//
//  XCTestManifests.swift
//  LocalStorage
//
//  Created by Gustavo Perdomo on 4/16/18.
//  Copyright © 2018 Gustavo Perdomo. All rights reserved.
//

import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(LocalAdapterTests.allTests)
    ]
}
#endif
