import XCTest

import StorageLocalTests

var tests = [XCTestCaseEntry]()
tests += StorageLocalTests.allTests()
XCTMain(tests)