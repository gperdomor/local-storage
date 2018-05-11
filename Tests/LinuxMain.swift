//
//  LinuxMain.swift
//  LocalStorage
//
//  Created by Gustavo Perdomo on 4/16/18.
//  Copyright © 2018 Gustavo Perdomo. All rights reserved.
//

import XCTest

import LocalStorageTests

var tests = [XCTestCaseEntry]()
tests += LocalStorageTests.allTests()
XCTMain(tests)
