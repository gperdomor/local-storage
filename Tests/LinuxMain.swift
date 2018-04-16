//
//  LinuxMain.swift
//  StorageLocal
//
//  Created by Gustavo Perdomo on 4/16/18.
//  Copyright © 2018 Gustavo Perdomo. All rights reserved.
//

import XCTest

import StorageLocalTests

var tests = [XCTestCaseEntry]()
tests += StorageLocalTests.allTests()
XCTMain(tests)
